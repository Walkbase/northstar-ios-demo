import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
        // TODO: Improve navigation. (#48)
        ZStack {
            if appData.isLoggedIn {
                MapView()
                    .transition(.move(edge: .trailing))
            } else {
                LoginView()
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut, value: appData.isLoggedIn)
    }
}

#Preview {
    @Previewable @StateObject var appData = AppData()

    ContentView()
        .environmentObject(appData)
}
