import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
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
