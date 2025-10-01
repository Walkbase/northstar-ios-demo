import Alamofire
import Northstar
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appData: AppData

    @State private var hideInput = true
    @State private var isLoading = false
    @State private var showAlert = false

    enum Field {
        case apiKey, email, password
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("Region", selection: $appData.selectedRegion) {
                        ForEach(appData.regions, id: \.name) { region in
                            Text(region.name).tag(region)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onAppear {
                        UISegmentedControl.appearance().setTitleTextAttributes(
                            [.foregroundColor: UIColor.black],
                            for: .selected
                        )
                        UISegmentedControl.appearance().setTitleTextAttributes(
                            [.foregroundColor: UIColor.white],
                            for: .normal
                        )
                    }

                    Label {
                        TextField("Email", text: $appData.email)
                            // TODO: Check modifiers. (#52)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                    } icon: {
                        Image(systemName: "envelope")
                    }
                    .onTapGesture {
                        focusedField = .email
                    }
                    .onSubmit {
                        focusedField = .password
                    }

                    Label {
                        HStack {
                            Group {
                                if hideInput {
                                    SecureField(
                                        "Password",
                                        text: $appData.password
                                    )
                                } else {
                                    TextField(
                                        "Password",
                                        text: $appData.password
                                    )
                                    // TODO: Check modifiers. (#52)
                                    .autocorrectionDisabled()
                                    .keyboardType(.alphabet)
                                    .textInputAutocapitalization(.never)
                                }
                            }
                            // TODO: Check modifiers. (#52)
                            .textContentType(.password)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .password)

                            if !appData.password.isEmpty {
                                Image(
                                    systemName: hideInput ? "eye" : "eye.slash"
                                )
                                .onTapGesture {
                                    hideInput.toggle()
                                    DispatchQueue.main.async {
                                        focusedField = .password
                                    }
                                }
                            }
                        }

                    } icon: {
                        Image(systemName: "lock")
                    }
                    .onTapGesture {
                        focusedField = .password
                    }
                    .onSubmit {
                        focusedField = .apiKey
                    }

                    Label {
                        TextField("API Key", text: $appData.apiKey)
                            // TODO: Check modifiers. (#52)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .apiKey)
                    } icon: {
                        Image(systemName: "key")
                    }
                    .onTapGesture {
                        focusedField = .apiKey
                    }
                    .onSubmit {
                        Task { await submit() }
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(isLoading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                    .fontWeight(.bold)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.white)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                .alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                    viewDimensions.width
                }
                .alert(
                    "Something Went Wrong",
                    isPresented: $showAlert
                ) {
                    Button("OK", role: .cancel) {
                    }
                    .background(.blue)
                    .foregroundStyle(.white)
                } message: {
                    Text(
                        "We could not sign you in. Please check your internet connection, chosen region, and login credentials, and try again."
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Image("NightSky"))
        .foregroundStyle(.white)
        .scrollDismissesKeyboard(.interactively)
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
            appData.isLoggedIn = true
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
