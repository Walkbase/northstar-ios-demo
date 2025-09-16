import Combine
import SwiftUI

@main
struct NorthstarDemoApp: App {
    @StateObject private var appData = AppData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
        }
    }
}

class AppData: ObservableObject {
    let regions = [
        Region(modifier: "", name: "EU"),
        Region(modifier: "-uk", name: "UK"),
        Region(modifier: "-us", name: "US"),
        Region(modifier: "-dev", name: "DEV"),
    ]
    @Published var selectedRegion: Region

    init() {
        selectedRegion = regions[0]
    }

    struct Region: Hashable {
        let modifier: String
        let name: String
    }
}
