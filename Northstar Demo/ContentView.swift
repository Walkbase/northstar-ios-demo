import SwiftUI

struct ContentView: View {
    @State private var sdkVersion: String?
    @State private var showLogin = false

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Group {
                Button("Set Up") {
                    showLogin = true
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
