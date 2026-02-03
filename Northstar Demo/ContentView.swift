import Northstar
import SwiftUI

struct ContentView: View {
    @State private var positioning: Positioning?

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                if let positioning {
                    MapView(
                        onLogout: {
                            withAnimation(.easeInOut) {
                                self.positioning = nil
                            }
                        },
                        positioning: positioning
                    )
                    .transition(.opacity)
                } else {
                    LoginView(onLogin: { positioning in
                        withAnimation(.easeInOut) {
                            self.positioning = positioning
                        }
                    })
                    .transition(.opacity)
                }
            }
            Tab("Minimal", systemImage: "lightbulb.min.fill") {
                BasicUsageView()
            }
        }
    }
}

// MARK: Previews

#Preview {
    ContentView()
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
