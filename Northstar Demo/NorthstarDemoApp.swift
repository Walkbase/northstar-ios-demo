import Combine
import Northstar
import Sentry
import SwiftUI

@main
struct NorthstarDemoApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var positioning = Positioning()

    init() {
        SentrySDK.start { options in
            options.dsn =
                "https://34af7cdc7896099c990e292bf98cab23@o20669.ingest.us.sentry.io/4510187418222593"
            options.tracesSampleRate = 0.02
            options.experimental.enableLogs = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(positioning)
        }
    }
}

class AppData: ObservableObject {
    @Published var apiKey = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var shouldCheckLoginStatus = true

    @Published var selectedRegion: Region
    let regions = [
        Region(modifier: "-dev", name: .dev),
        Region(modifier: "", name: .eu),
        Region(modifier: "-uk", name: .uk),
        Region(modifier: "-us", name: .us),
    ]

    // TODO: Can we auto-select this based on your location? (#50).
    init() {
        selectedRegion = regions[0]
    }

    struct Region: Hashable {
        let modifier: String
        let name: Northstar.Region
    }
}
