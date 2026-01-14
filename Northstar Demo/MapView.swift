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

    var body: some View {
        TileOverlayMapView(
            positioning: positioning,
            selectedRegion: selectedRegion
        )
        .ignoresSafeArea()
        .onAppear {
            positioning.start(
                in: selectedRegion,
                apiKey: apiKey
            )
        }
        // TODO: Improve if we loose our position. (#40)
        .overlay {
            if positioning.position == nil {
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
            DiagnosticsView(positioning: positioning)
        }
    }
}

private struct TileOverlayMapView: UIViewRepresentable {
    var positioning: Positioning
    var selectedRegion: Northstar.Region

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
        guard let position = positioning.position else { return }

        let coordinate = CLLocationCoordinate2D(
            latitude: position.lat,
            longitude: position.lng
        )

        if let annotation = context.coordinator.annotation {
            annotation.coordinate = coordinate
        } else {
            let annotation = MKPointAnnotation(coordinate: coordinate)
            mapView.addAnnotation(annotation)
            context.coordinator.annotation = annotation
        }

        let floorID = position.floor_id
        if floorID != context.coordinator.floorID {
            context.coordinator.floorID = floorID

            Task {
                let floor = await fetchFloor(floorID: floorID)

                guard let floor else { return }

                let urlTemplate =
                    "https://analytics-\(selectedRegion).walkbase.com/tiles/\(floor.tiles.id)/{z}/{x}/{y}.\(floor.tiles.format)"
                let overlay = MKTileOverlay(urlTemplate: urlTemplate)
                overlay.maximumZ = floor.tiles.max_zoom
                overlay.minimumZ = floor.tiles.min_zoom
                mapView.addOverlay(overlay, level: .aboveRoads)

                mapView.setCamera(
                    MKMapCamera(
                        lookingAtCenter: CLLocationCoordinate2D(
                            latitude: position.lat,
                            longitude: position.lng
                        ),
                        // TODO: Calculate from polygon if possible. Or maybe we can zoom in on the overlay directly? (#39)
                        fromDistance: 200,
                        pitch: 0,
                        heading: floor.bearing
                    ),
                    animated: true
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var annotation: MKPointAnnotation?
        var floorID: Int?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay)
            -> MKOverlayRenderer
        {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    // TODO: Should throw instead of returning `nil`. (#41).
    private func fetchFloor(floorID: Int) async -> FloorResponse? {
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

private struct DiagnosticsView: View {
    var positioning: Positioning

    @Namespace private var animation
    @State private var showPositioningDiagnostics = false

    var body: some View {
        Group {
            if !positioning.diagnostics.all.isEmpty {
                let content = ForEach(positioning.diagnostics.all) {
                    diagnostic in
                    PositioningDiagnostic(
                        expanded: showPositioningDiagnostics,
                        message: diagnostic.information,
                        namespace: animation,
                        severity: diagnostic.severity,
                        type: diagnostic
                    )
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

private struct PositioningDiagnostic: View {
    let expanded: Bool
    let message: String
    let namespace: Namespace.ID
    let severity: Diagnostic.Severity
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
    var information: String {
        switch self {
        case .bluetooth(let diagnostic):
            switch diagnostic {
            case .missingCapability:
                return
                    "A Bluetooth error occurred due to a configuration problem.\nPlease contact the app developer(s)."
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
        case .location(let diagnostic):
            switch diagnostic {
            case .denied:
                return
                    "Location access denied.\nPositioning performance will be reduced. Enable location access in Settings for better positioning."
            case .missingCapability:
                return
                    "Location access restricted due to a configuration problem.\nPlease contact the app developer(s)."
            case .restricted:
                return
                    "Location access restricted due to system-wide restrictions.\nPositioning performance will be reduced."
            @unknown default:
                return "An unexpected location diagnostic occurred."
            }
        case .motionData(let diagnostic):
            switch diagnostic {
            case .denied:
                return
                    "Motion data access denied.\nPositioning performance will be reduced. Enable motion data access in Settings for better positioning."
            case .missingCapability:
                return
                    "Motion data access restricted due to a configuration problem.\nPlease contact the app developer(s)."
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
            case .constrained:
                return
                    "Limited bandwidth available.\nPositioning performance may be reduced. Connect to a Wi-Fi network if possible."
            case .expensive:
                return
                    "You are using cellular data.\nPositioning performance may be reduced. Connect to a Wi-Fi network if possible."
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
