import Alamofire
import MapKit
import Northstar
import Sentry
import SwiftUI

private let logger = SentrySDK.logger

struct MapView: View {
    @Environment(AppData.self) var appData: AppData
    @Environment(Positioning.self) var positioning: Positioning

    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("selectedRegion") var selectedRegion: Northstar.Region = .dev
    @AppStorage("shouldCheckLoginStatus") var shouldCheckLoginStatus = false

    @State private var bearing: Double?
    @State private var floorID: Int?
    @State private var maxZoom: Int?
    @State private var minZoom: Int?
    @State private var urlTemplate: String?

    var body: some View {
        TileOverlayMapView(
            bearing: bearing,
            location: positioning.location,
            maxZoom: maxZoom,
            minZoom: minZoom,
            urlTemplate: urlTemplate
        )
        .ignoresSafeArea()
        .task {
            await positioning.start(
                using: apiKey,
                in: selectedRegion
            )
        }
        .onChange(of: positioning.location) { oldLocation, location in
            guard let latestFloorID = location?.floor_id else {
                // TODO: Should we start a timer to clear the map? (#40)
                return
            }

            if floorID != latestFloorID {
                Task {
                    let floor = await fetchFloor(
                        using: latestFloorID
                    )
                    // TODO: Remove when `fetchFloor` throws. (#41).
                    if let floor {
                        bearing = floor.bearing
                        maxZoom = floor.tiles.max_zoom
                        minZoom = floor.tiles.min_zoom
                        // TODO: Abstract to `appData`. (#53)
                        urlTemplate =
                            "https://analytics-\(selectedRegion).walkbase.com/tiles/\(floor.tiles.id)/{z}/{x}/{y}.\(floor.tiles.format)"
                        floorID = latestFloorID
                    }
                }
            }
        }
        // TODO: Improve if we loose our location. (#40)
        .overlay {
            if positioning.location == nil && floorID == nil {
                ProgressView {
                    Text("Positioning...")
                }
            }
        }
        .overlay(
            Menu {
                Button {
                    Task {
                        positioning.stop()

                        let response = await AF.request(
                            "https://analytics-\(selectedRegion).walkbase.com/api/j/logout",
                            method: .post
                        )
                        .validate()
                        // TODO: Remove when backend is fixed. (#82)
                        .serializingData(emptyResponseCodes: [200])
                        .response

                        switch response.result {
                        case .success:
                            shouldCheckLoginStatus = false
                            withAnimation(.easeInOut) {
                                appData.isLoggedIn = false
                            }
                        case .failure(let error):
                            if let statusCode = response.response?.statusCode {
                                logger.error("HTTP status code: \(statusCode)")
                            }

                            if let data = response.data,
                                let serverMessage = String(
                                    data: data,
                                    encoding: .utf8
                                )
                            {
                                logger.error("Server message: \(serverMessage)")
                            }

                            logger.error("Error: \(error)")
                            SentrySDK.capture(error: error)
                        }
                    }
                } label: {
                    Label(
                        "Sign Out",
                        systemImage: "iphone.and.arrow.forward.outward"
                    )
                }
            } label: {
                Image(systemName: "line.3.horizontal.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.gray, .background)
                    .padding()
            },
            alignment: .topLeading
        )
    }

    // TODO: Should throw instead of returning `nil`. (#41).
    private func fetchFloor(using floorID: Int) async -> FloorResponse? {
        // TODO: Abstract to `appData`. (#53)
        let response = await AF.request(
            "https://analytics-\(selectedRegion).walkbase.com/api/j/floors/v2/\(floorID)"
        )
        .validate()
        .serializingData()
        .response

        switch response.result {
        case .success(let data):
            do {
                return try JSONDecoder().decode(
                    FloorResponse.self,
                    from: data
                )
            } catch {
                logger.error("Decoding error: \(error)")
                SentrySDK.capture(error: error)
                return nil
            }

        case .failure(let error):
            if let statusCode = response.response?.statusCode {
                logger.error("HTTP status code: \(statusCode)")
            }

            if let data = response.data,
                let serverMessage = String(data: data, encoding: .utf8)
            {
                logger.error("Server message: \(serverMessage)")
            }

            SentrySDK.capture(error: error)

            return nil
        }
    }

    private struct FloorResponse: Decodable {
        // Only a subset of the response fields are used in this demo.
        let bearing: Double
        let tiles: Tiles

        struct Tiles: Decodable {
            let format: String
            let id: String
            let max_zoom: Int
            let min_zoom: Int
        }
    }
}

private struct TileOverlayMapView: UIViewRepresentable {
    var bearing: Double?
    var location: Location?
    var maxZoom: Int?
    var minZoom: Int?
    var urlTemplate: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // Remove labels.
        let config = MKStandardMapConfiguration()
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if let bearing, let location, let urlTemplate {
            if context.coordinator.isFirstUpdate {
                mapView.removeAnnotations(mapView.annotations)
                mapView.removeOverlays(mapView.overlays)

                let annotation = MKPointAnnotation(
                    coordinate: CLLocationCoordinate2D(
                        latitude: location.lat,
                        longitude: location.lng
                    )
                )
                mapView.addAnnotation(annotation)
                context.coordinator.currentAnnotation = annotation

                let overlay = MKTileOverlay(urlTemplate: urlTemplate)
                minZoom.map { overlay.minimumZ = $0 }
                maxZoom.map { overlay.maximumZ = $0 }
                mapView.addOverlay(
                    overlay,
                    level: .aboveRoads
                )

                mapView.setCamera(
                    MKMapCamera(
                        lookingAtCenter: CLLocationCoordinate2D(
                            latitude: location.lat,
                            longitude: location.lng
                        ),
                        // TODO: Calculate from polygon if possible. Or maybe we can zoom in on the overlay directly? (#39)
                        fromDistance: 200,
                        pitch: 0,
                        heading: bearing
                    ),
                    animated: true
                )

                context.coordinator.isFirstUpdate = false
            } else {
                if let currentAnnotation = context.coordinator.currentAnnotation
                {
                    currentAnnotation.coordinate = CLLocationCoordinate2D(
                        latitude: location.lat,
                        longitude: location.lng
                    )
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentAnnotation: MKPointAnnotation?
        var isFirstUpdate = true

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay)
            -> MKOverlayRenderer
        {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview {
    @Previewable var appData = AppData()
    @Previewable var positioning = Positioning()

    MapView().environment(appData).environment(positioning)
}
