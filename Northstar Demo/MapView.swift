import Alamofire
import MapKit
import Northstar
import SwiftUI

struct MapView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var positioning: Positioning
    @State private var bearing: Double?
    @State private var floorID: Int?
    @State private var urlTemplate: String?

    var body: some View {
        HStack {
            Button {
                positioning.stop()
                withAnimation(.easeInOut) {
                    appData.isLoggedIn = false
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .padding()

            Spacer()
        }

        TileOverlayMapView(
            bearing: bearing,
            location: positioning.location,
            urlTemplate: urlTemplate
        )
        .task {
            // TODO: Handle throws when implemented. (#40)
            await positioning.registerDevice(
                using: appData.apiKey,
                in: appData.selectedRegion.name,
                // TODO: What casing should we use? (#20, SDK)
                for: "northstar-demo"
            )
            await positioning.start(
                using: appData.apiKey,
                in: appData.selectedRegion.name
            )
        }
        .onReceive(positioning.$location) { location in
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
                        // TODO: Abstract to `appData`. (#53)
                        urlTemplate =
                            "https://analytics\(appData.selectedRegion.modifier).walkbase.com/tiles/\(floor.tiles.id)/{z}/{x}/{y}.\(floor.tiles.format)"
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
    }

    // TODO: Should throw instead of returning `nil`. (#41).
    private func fetchFloor(using floorID: Int) async -> FloorResponse? {
        // TODO: Abstract to `appData`. (#53)
        let response = await AF.request(
            "https://analytics\(appData.selectedRegion.modifier).walkbase.com/api/j/floors/v2/\(floorID)"
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
                print("Decoding error: \(error)")
                return nil
            }

        case .failure(let error):
            print("Error: \(error)")

            if let statusCode = response.response?.statusCode {
                print("HTTP status code: \(statusCode)")
            }

            if let data = response.data,
                let serverMessage = String(data: data, encoding: .utf8)
            {
                print("Server message: \(serverMessage)")
            }

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
    var urlTemplate: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
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

                // TODO: Zooming in full shows no overlay tiles. (#51)
                mapView.addOverlay(
                    MKTileOverlay(urlTemplate: urlTemplate),
                    // TODO: Can we use `.aboveRoads` and hide labels instead? (#54)
                    level: .aboveLabels
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
    @Previewable @StateObject var appData = AppData()
    @Previewable @StateObject var positioning = Positioning()

    MapView()
        .environmentObject(appData)
        .environmentObject(positioning)
}
