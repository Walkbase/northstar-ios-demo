import MapKit
import SwiftUI

struct MapView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TileOverlayMapView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
        }
    }
}

private struct TileOverlayMapView: UIViewRepresentable {
    let urlTemplate = "TODO"

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.addOverlay(
            MKTileOverlay(urlTemplate: urlTemplate),
            level: .aboveRoads
        )
        mapView.delegate = context.coordinator

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
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
    MapView()
}
