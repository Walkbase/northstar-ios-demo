import Alamofire
import Northstar
import SwiftUI

struct ContentView: View {
    @State private var positioning: Positioning?

    var body: some View {
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
}

// MARK: Previews

#Preview {
    ContentView()
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
