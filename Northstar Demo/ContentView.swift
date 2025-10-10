import Alamofire
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appData: AppData

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
    @Previewable @StateObject var appData = AppData()

    ContentView()
        .environmentObject(appData)
}
