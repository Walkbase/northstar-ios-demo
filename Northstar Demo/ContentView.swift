import Alamofire
import SwiftUI

struct ContentView: View {
    @Environment(AppData.self) private var appData: AppData

    var body: some View {
        if appData.isLoggedIn {
            MapView()
                .transition(.opacity)
        } else {
            LoginView()
                .transition(.opacity)
        }
    }
}

#Preview {
    @Previewable var appData = AppData()

    ContentView().environment(appData)
}
