import Northstar
import SwiftUI

struct BasicUsageView: View {
    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("selectedRegion") var selectedRegion: Northstar.Region = .dev

    @State private var positioning: Positioning?
    @State private var positioningStatus: String = ""

    @State private var isLoading = false

    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Grid(alignment: .leading) {
            GridRow {
                var isDisabled: Bool { positioning != nil }

                Text("Region:")
                Picker("Region", selection: $selectedRegion) {
                    ForEach(Northstar.Region.allCases, id: \.self) { region in
                        Text(region.rawValue.uppercased()).tag(region)
                    }
                }
                .border(.blue)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1)
            }

            GridRow {
                var isDisabled: Bool { positioning != nil }

                Text("API Key:")
                TextField("", text: $apiKey)
                    .border(.blue)
                    .submitLabel(.go)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.5 : 1)
            }
            .onSubmit { Task { await start() } }

            GridRow {
                var canStart: Bool {
                    positioning == nil || positioning?.status == .stopped
                }

                Button {
                    Task { canStart ? await start() : stop() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(canStart ? "Start" : "Stop")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
                    .background(.blue)
                    .textCase(.uppercase)
                    .fontWeight(.bold)
                }
                .gridCellColumns(2)
            }

            GridRow {
                var isDisabled: Bool {
                    positioning == nil || positioning?.status != .stopped
                }

                Button {
                    positioning = nil
                } label: {
                    Text("Reset")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(.blue)
                        .textCase(.uppercase)
                        .fontWeight(.bold)
                }
                .gridCellColumns(2)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.5 : 1)
            }

            Divider().hidden()

            GridRow {
                Text("Status:")
                Text(positioningStatus)
            }
            .onChange(of: positioning?.status) { _, status in
                switch status {
                case .none:
                    positioningStatus = "Positioning not started"
                case .stopped:
                    positioningStatus = "⏹️ Positioning stopped"
                case .connectingToStream, .reconnecting, .starting,
                    .waitingForNetwork:
                    positioningStatus = "⏳ Positioning starting"
                case .waitingForUpdates:
                    positioningStatus = "⏳ Finding your position"
                case .receivingUpdates:
                    positioningStatus = "✅ Tracking your position"
                @unknown default:
                    positioningStatus = "❌ Something went wrong"
                }
            }

            GridRow(alignment: .top) {
                Text("Position:")
                Group {
                    if let position = positioning?.position {
                        Text(
                            "Timestamp: \(position.timestamp)\nLatitude: \(position.lat)\nLongitude: \(position.lng)"
                        )
                    } else {
                        Text("None received yet")
                    }
                }
            }
        }
        .padding()
        .alert("Something Went Wrong", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func start() async {
        isLoading = true

        let positioning =
            self.positioning
            ?? Positioning(
                apiKey: apiKey,
                region: selectedRegion,
                logger: logger
            )

        do {
            try await positioning.start(userID: "User 123")
            self.positioning = positioning

        } catch {
            alertMessage =
                "We could not validate your API key.\n\nPlease check your internet connection, chosen region, API key and try again."
            showAlert = true
        }

        isLoading = false
    }

    private func stop() {
        positioning?.stop()
    }
}

private struct DemoLogger: Northstar.Logger {
    func error(_ message: String) { print(message) }
    func info(_ message: String) { print(message) }
    func warning(_ message: String) { print(message) }
}

private let logger = DemoLogger()

// MARK: Previews

#Preview {
    BasicUsageView()
}

#Preview {
    BasicUsageView().preferredColorScheme(.dark)
}
