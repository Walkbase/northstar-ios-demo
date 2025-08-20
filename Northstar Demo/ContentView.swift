import Northstar
import SwiftUI

struct ContentView: View {
    private let positioning = Positioning()

    @State private var sdkVersion: String?
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
                }
                Button("Set Up") {
                    showLogin = true
                }
                Button("Register Device") {
                    Task {
                        await positioning.registerDevice(
                            apiKey: apiKey,
                            userID: "northstar-demo"
                        )
                    }
                }
            }
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(.capsule)
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
