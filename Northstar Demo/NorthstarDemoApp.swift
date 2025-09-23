import Combine
import Northstar
import SwiftUI

@main
struct NorthstarDemoApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var positioning = Positioning()

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

    @Published var selectedRegion: Region
    let regions = [
        Region(modifier: "", name: "EU"),
        Region(modifier: "-uk", name: "UK"),
        Region(modifier: "-us", name: "US"),
        Region(modifier: "-dev", name: "DEV"),
    ]

    init() {
        selectedRegion = regions[0]
    }

    struct Region: Hashable {
        let modifier: String
        let name: String
    }
}
