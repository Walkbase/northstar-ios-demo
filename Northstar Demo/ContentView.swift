import Northstar
import SwiftUI

struct ContentView: View {
    private let positioning = WalkbasePositioning()
    
    @State private var sdkVersion: String?
    @State private var showAlert = false
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("SDK test") {
                positioning.test()
                sdkVersion = positioning.version()
                showAlert = true
            }
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(.capsule)
            .alert("Northstar SDK Information", isPresented: $showAlert) {
                Button("Close", role: .cancel) {}
            } message: {
                Text("Version: \(sdkVersion ?? "N/A")")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
