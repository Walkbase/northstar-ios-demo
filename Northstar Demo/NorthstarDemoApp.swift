import Combine
import Northstar
import Sentry
import SwiftUI

@main
struct NorthstarDemoApp: App {
    private var appData = AppData()
    private var positioning = Positioning()

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
                .environment(appData)
                .environment(positioning)
        }
    }
}

@Observable
class AppData {
    var isLoggedIn = false
}
