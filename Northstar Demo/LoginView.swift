import Alamofire
import Northstar
import SwiftUI

struct LoginView: View {
    @Environment(\.defaultMinListRowHeight) private var defaultMinListRowHeight
    @EnvironmentObject private var appData: AppData

    @State private var hideInput = true
    @State private var isLoading = false
    @State private var rotate = false
    @State private var showAlert = false

    enum Field {
        case apiKey, email, password
    }
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

                    if appData.shouldCheckLoginStatus {
                        Spacer()
                        ProgressView().tint(.white)
                        Text("Checking your sign-in status…")
                        Spacer()
                    } else {
                        VStack {
                            Picker("Region", selection: $appData.selectedRegion)
                            {
                                ForEach(appData.regions, id: \.name) { region in
                                    Text(region.name.rawValue.uppercased())
                                        .tag(region)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onAppear {
                                UISegmentedControl.appearance()
                                    .setTitleTextAttributes(
                                        [.foregroundColor: UIColor.black],
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
                                        text: $appData.email,
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
                                        ZStack {
                                            SecureField(
                                                "",
                                                text: $appData.password,
                                                prompt: Text("Password")
                                                    .foregroundStyle(.gray)
                                            )
                                            .opacity(hideInput ? 1 : 0)

                                            TextField(
                                                "",
                                                text: $appData.password,
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

                                        if !appData.password.isEmpty {
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
                                        text: $appData.apiKey,
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

                            Divider().background(.clear)

                            Button {
                                Task { await submit() }
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
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
                        .alert(
                            "Something Went Wrong",
                            isPresented: $showAlert
                        ) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(
                                "We could not sign you in. Please check your internet connection, chosen region, and login credentials, and try again."
                            )
                        }
                    }

                    if isKeyboardHidden {
                        Spacer()

                        Image("Walkbase")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .transition(.opacity)
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
            .onChange(of: focusedField) { _, latestFocusedField in
                isKeyboardHidden = latestFocusedField == nil
            }
            .onTapGesture { focusedField = nil }
            .scrollDismissesKeyboard(.interactively)
            .animation(.easeInOut, value: isKeyboardHidden)
        }
        .task {
            guard appData.shouldCheckLoginStatus else { return }

            let start = Date()

            let response = await AF.request(
                "https://analytics\(appData.selectedRegion.modifier).walkbase.com/api",
                method: .head
            ).validate().serializingData().response

            // Ensure the sign-in check takes long enough to prevent flicker.
            let elapsed = Date().timeIntervalSince(start)
            let minimumShowDuration = 2.0  // seconds
            if elapsed < minimumShowDuration {
                try? await Task.sleep(
                    for: .seconds(minimumShowDuration - elapsed)
                )
            }

            if case .success = response.result {
                withAnimation(.easeInOut) {
                    appData.isLoggedIn = true
                } completion: {
                    appData.shouldCheckLoginStatus = false
                }
            } else {
                withAnimation(.easeInOut) {
                    appData.isLoggedIn = false
                    appData.shouldCheckLoginStatus = false
                }
            }
        }
    }

    // MARK: Methods

    private func submit() async {
        focusedField = nil
        isLoading = true
        await logIn()
        isLoading = false
    }

    private func logIn() async {
        // TODO: Abstract to `appData`. (#53)
        let url = URL(
            string:
                "https://analytics\(appData.selectedRegion.modifier).walkbase.com/api/j/login"
        )!
        let parameters: Parameters = [
            "username": appData.email, "password": appData.password,
        ]
        let headers: HTTPHeaders = ["W-SDK-Client-API-Key": appData.apiKey]

        let response = await AF.request(
            url,
            method: .post,
            parameters: parameters,
            headers: headers,
        ).validate().serializingData().response

        if case .success = response.result {
            withAnimation(.easeInOut) {
                appData.isLoggedIn = true
            }
        } else {
            appData.isLoggedIn = false
            showAlert = true
        }
    }
}

// MARK: Preview

#Preview {
    @Previewable @StateObject var appData = AppData()

    LoginView()
        .environmentObject(appData)
}
