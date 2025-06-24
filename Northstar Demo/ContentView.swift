import Northstar
import SwiftUI

struct ContentView: View {
    private let positioning = WalkbasePositioning()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("SDK test") {
                positioning.test()
            }
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(.capsule)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
