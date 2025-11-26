import Alamofire
import Northstar
import SwiftUI

struct ContentView: View {
    @Environment(AppData.self) private var appData: AppData
    @State private var positioning: Positioning?

    var body: some View {
        if appData.isLoggedIn, let positioning {
            MapView(positioning: positioning)
                .transition(.opacity)
                .onDisappear {
                    self.positioning = nil
                }
        } else {
            LoginView(onLogin: { positioning in
                self.positioning = positioning
            })
            .transition(.opacity)
        }
    }
}

#Preview {
    @Previewable var appData = AppData()

    ContentView().environment(appData)
}
