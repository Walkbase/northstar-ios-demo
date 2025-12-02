import Alamofire
import MapKit
import Northstar
import Sentry
import SwiftUI

private let logger = SentrySDK.logger

struct MapView: View {
    var onLogout: () -> Void
    var positioning: Positioning

    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("selectedRegion") var selectedRegion: Northstar.Region = .dev
    @AppStorage("shouldCheckLoginStatus") var shouldCheckLoginStatus = false

    @State private var bearing: Double?
    @State private var floorID: Int?
    @State private var maxZoom: Int?
    @State private var minZoom: Int?
    @State private var urlTemplate: String?

    @Namespace private var animation
    @State private var showPositioningDiagnostics = false

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
        .overlay(alignment: .topLeading) {
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
                            onLogout()
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
            }
        }
        .overlay(alignment: .top) {
            Group {
                if positioning.diagnostics.all.isEmpty == false {

                    let content = Group {
                        ForEach(positioning.diagnostics.all) { diagnostic in
                            PositioningDiagnostic(
                                expanded: showPositioningDiagnostics,
                                message: diagnostic.message,
                                namespace: animation,
                                severity: diagnostic.severity,
                                type: diagnostic
                            )
                        }
                    }

                    Group {
                        if showPositioningDiagnostics {
                            VStack(alignment: .leading, spacing: 16) {
                                content
                            }
                        } else {
                            HStack {
                                content
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(.background)
            .clipShape(.rect(cornerRadius: 8))
            .onTapGesture {
                withAnimation { showPositioningDiagnostics.toggle() }
            }
            .animation(.easeInOut, value: positioning.diagnostics)
        }
    }

    // TODO: Should throw instead of returning `nil`. (#41).
    private func fetchFloor(using floorID: Int) async -> FloorResponse? {
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

private struct PositioningDiagnostic: View {
    let expanded: Bool
    let message: String
    let namespace: Namespace.ID
    let severity: DiagnosticSeverity
    let type: Diagnostic

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(
                systemName: severity == .error
                    ? "exclamationmark.octagon.fill"
                    : "exclamationmark.triangle.fill"
            )
            .matchedGeometryEffect(id: type, in: namespace)

            if expanded {
                Text(message)
            }
        }
        .foregroundStyle(severity == .error ? .red : .orange)
    }
}

extension Diagnostic {
    var message: String {
        switch self {
        case .bluetooth(let diagnostic):
            switch diagnostic {
            case .poweredOff:
                return "Bluetooth is turned off.\nPlease enable it in Settings."
            case .resetting:
                return "Bluetooth is restarting.\nPlease wait."
            case .unauthorized:
                return
                    "This app needs Bluetooth permission.\nPlease enable it in Settings."
            case .unknown:
                return
                    "A Bluetooth error occurred.\nTry restarting Bluetooth or your device."
            case .unsupported:
                return
                    "This device does not support Bluetooth LE.\nA compatible device is required."
            @unknown default:
                return "An unexpected Bluetooth diagnostic occurred."
            }
        case .motionData(let diagnostic):
            switch diagnostic {
            case .denied:
                return
                    "Motion data access denied.\nPositioning performance will be reduced. Enable motion data access in Settings for better positioning."
            case .restricted:
                return
                    "Motion data access restricted due to system-wide restrictions.\nPositioning performance will be reduced."
            case .unavailable:
                return
                    "Motion data unavailable on this device.\nPositioning performance will be reduced."
            @unknown default:
                return "An unexpected motion data diagnostic occurred."
            }
        case .network(let diagnostic):
            switch diagnostic {
            case .requiresConnection:
                return
                    "No internet connection.\nYou may need to connect to Wi-Fi, enable cellular data, or sign in to a network."
            case .unsatisfied:
                return
                    "No internet connection.\nPlease check your network settings."
            @unknown default:
                return "An unexpected network diagnostic occurred."
            }
        @unknown default:
            return "An unexpected diagnostic occurred."
        }
    }
}

// MARK: Previews

#Preview {
    @Previewable var positioning = Positioning()
    MapView(onLogout: {}, positioning: positioning)
}

#Preview {
    @Previewable var positioning = Positioning()
    MapView(onLogout: {}, positioning: positioning).preferredColorScheme(.dark)
}
