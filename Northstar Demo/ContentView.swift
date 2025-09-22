import SwiftUI

struct ContentView: View {
    @State private var showLoginView = false
    @State private var showMapView = false

    var body: some View {
        VStack {
            Group {
                Button("Set Up") {
                    showLoginView = true
                }
                Button("Show Map") {
                    showMapView = true
                }
            }
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(.capsule)
        }
        .padding()
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
        .sheet(isPresented: $showMapView) {
            MapView()
        }
    }
}

#Preview {
    ContentView()
}
