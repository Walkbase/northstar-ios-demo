import Northstar
import SwiftUI

struct ContentView: View {
    private let positioning = Positioning()

    @State private var sdkVersion: String?
    @State private var showAlert = false
    @State private var showLogin = false

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Group {
                Button("SDK Test") {
                    positioning.test()
                    sdkVersion = positioning.version()
                    showAlert = true
                }
                Button("Set Up") {
                    showLogin = true
                }
                Button("Register Device") {
                    Task {
                        await positioning.registerDevice(
                            apiKey: "8EwLYyygHNWPhK1PxvMJ"
                        )
                    }
                }
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
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
