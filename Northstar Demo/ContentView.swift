import SwiftUI
import Northstar

struct ContentView: View {
    private let demo = Demo()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("Demo") {
                self.demo.greet()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
