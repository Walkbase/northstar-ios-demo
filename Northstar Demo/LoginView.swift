import Alamofire
import Logging
import Northstar
import SwiftUI

struct LoginView: View {
    var onLogin: (_ positioning: Positioning) -> Void

    @Environment(\.defaultMinListRowHeight) private var defaultMinListRowHeight

    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("email") var email = ""
    @AppStorage("selectedRegion") var selectedRegion: Northstar.Region = .dev
    @AppStorage("shouldCheckLoginStatus") var shouldCheckLoginStatus = false

    @State private var hideInput = true
    @State private var password = ""

    @State private var alertMessage = ""
    @State private var showAlert = false

    @State private var isLoading = false
    @State private var rotate = false

    enum Field { case apiKey, email, password }
    @FocusState private var focusedField: Field?
    /// Due to some SwiftUI limitation/bug, you can't animate directly off `@FocusState` changes.
    /// Fade-out (when focus is set) will animate, but fade-in (when focus clears) does not.
    /// You can mirror focus into a separate `@State` and control the animation from that as a workaround.
    @State private var isKeyboardHidden = true

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    if isKeyboardHidden {
                        Group {
                            Text("Northstar Demo")
                                .padding(.top)
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .fontDesign(.rounded)

                            Image("Northstar")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 150)
                                .foregroundStyle(
                                    Gradient(colors: [.white, .cyan])
                                )
                                .opacity(0.9)
                                .shadow(color: .white.opacity(0.5), radius: 25)
                                .blendMode(.hardLight)
                        }
                        .transition(.opacity)
                    }

                    VStack {
                        Picker("Region", selection: $selectedRegion) {
                            ForEach(Northstar.Region.allCases, id: \.self) {
                                region in
                                Text(region.rawValue.uppercased()).tag(region)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onAppear {
                            UISegmentedControl.appearance()
                                .setTitleTextAttributes(
                                    [.foregroundColor: UIColor.label],
                                    for: .selected
                                )
                            UISegmentedControl.appearance()
                                .setTitleTextAttributes(
                                    [.foregroundColor: UIColor.white],
                                    for: .normal
                                )
                        }

                        Grid(verticalSpacing: 0) {
                            GridRow {
                                Image(systemName: "envelope")
                                TextField(
                                    "",
                                    text: $email,
                                    prompt: Text("Email").foregroundStyle(
                                        .gray
                                    )
                                )
                                // TODO: Check modifiers. (#52)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                            }
                            .frame(minHeight: defaultMinListRowHeight)
                            .onTapGesture { focusedField = .email }
                            .onSubmit { focusedField = .password }

                            Divider().background(.white)

                            GridRow {
                                Image(systemName: "lock")
                                HStack {
                                    // TODO: Tab focus doesn't work properly, probably no biggie
                                    ZStack {
                                        SecureField(
                                            "",
                                            text: $password,
                                            prompt: Text("Password")
                                                .foregroundStyle(.gray)
                                        )
                                        .opacity(hideInput ? 1 : 0)

                                        TextField(
                                            "",
                                            text: $password,
                                            prompt: Text("Password")
                                                .foregroundStyle(.gray)
                                        )
                                        // TODO: Check modifiers. (#52)
                                        .autocorrectionDisabled()
                                        .keyboardType(.alphabet)
                                        .textInputAutocapitalization(.never)
                                        .opacity(hideInput ? 0 : 1)
                                    }
                                    // TODO: Check modifiers. (#52)
                                    .textContentType(.password)
                                    .submitLabel(.next)
                                    .focused(
                                        $focusedField,
                                        equals: .password
                                    )

                                    if !password.isEmpty {
                                        Image(
                                            systemName: hideInput
                                                ? "eye" : "eye.slash"
                                        )
                                        .onTapGesture { hideInput.toggle() }
                                    }
                                }
                            }
                            .frame(minHeight: defaultMinListRowHeight)
                            .onTapGesture { focusedField = .password }
                            .onSubmit { focusedField = .apiKey }

                            Divider().background(.white)

                            GridRow {
                                Image(systemName: "key")
                                TextField(
                                    "",
                                    text: $apiKey,
                                    prompt: Text("API Key").foregroundStyle(
                                        .gray
                                    )
                                )
                                // TODO: Check modifiers. (#52)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .apiKey)
                            }
                            .frame(minHeight: defaultMinListRowHeight)
                            .onTapGesture { focusedField = .apiKey }
                            .onSubmit { Task { await submit() } }

                            Divider().background(.white)
                        }

                        Divider().hidden()

                        Button {
                            Task { await submit() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .textCase(.uppercase)
                            .fontWeight(.bold)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                    .contentShape(Rectangle())  // Expands the tappable area of the view to its full bounds.
                    .onTapGesture {}  // Empty handler to swallow taps and prevent them from propagating to the parent.
                    .alert("Something Went Wrong", isPresented: $showAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(alertMessage)
                    }

                    if isKeyboardHidden {
                        Spacer()

                        Image("Walkbase")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .transition(.opacity)
                            .padding(.bottom)
                    }
                }
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height
                )
            }
            .background {
                Image("NightSky")
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(
                        .linear(duration: 200).repeatForever(
                            autoreverses: false
                        ),
                        value: rotate
                    )
                    .onAppear { rotate = true }
            }
            .foregroundStyle(.white)
            .onChange(of: focusedField) { _, focusedField in
                isKeyboardHidden = focusedField == nil
            }
            .onTapGesture { focusedField = nil }
            .scrollDismissesKeyboard(.interactively)
            .animation(.easeInOut, value: isKeyboardHidden)
        }
        .task {
            if shouldCheckLoginStatus {
                await login()
            }
        }
    }

    // MARK: Methods

    private func submit() async {
        focusedField = nil
        await login()
    }

    private func login() async {
        isLoading = true

        let request = {
            if shouldCheckLoginStatus {
                return AF.request(
                    "https://analytics-\(selectedRegion).walkbase.com/api/j/user",
                    method: .head
                )
            } else {
                let parameters: Parameters = [
                    "username": email, "password": password,
                ]
                return AF.request(
                    "https://analytics-\(selectedRegion).walkbase.com/api/j/login",
                    method: .post,
                    parameters: parameters
                )
            }
        }()

        let response = await request.validate().serializingData().response
        if case .failure = response.result {
            isLoading = false
            alertMessage =
                if shouldCheckLoginStatus {
                    "Your session has expired or there was a network issue.\n\nPlease check your internet connection, chosen region, and login credentials, then try again."
                } else {
                    "We could not sign you in.\n\nPlease check your internet connection, chosen region, and login credentials, then try again."
                }
            showAlert = true
            shouldCheckLoginStatus = false
            return
        }

        let positioning = Positioning(
            apiKey: apiKey,
            region: selectedRegion,
            logger: logger
        )

        withAnimation(.easeInOut) {
            onLogin(positioning)
        } completion: {
            isLoading = false
            shouldCheckLoginStatus = true
        }
    }
}

private struct DemoLogger: Northstar.Logger {
    private let swiftLogger = Logger(
        label: Bundle.main.bundleIdentifier ?? "N/A"
    )

    func error(_ message: String) {
        swiftLogger.error(Logger.Message(stringLiteral: message))
    }
    func info(_ message: String) {
        swiftLogger.info(Logger.Message(stringLiteral: message))
    }
    func warning(_ message: String) {
        swiftLogger.warning(Logger.Message(stringLiteral: message))
    }
}

private let logger = DemoLogger()

// MARK: Previews

#Preview {
    LoginView(onLogin: { _ in })
}

#Preview {
    LoginView(onLogin: { _ in }).preferredColorScheme(.dark)
}
