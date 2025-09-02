import Alamofire
import Northstar
import SwiftUI

private let regions = [
    Region(modifier: "", name: "EU"),
    Region(modifier: "-uk", name: "UK"),
    Region(modifier: "-us", name: "US"),
    Region(modifier: "-dev", name: "Dev"),
]

struct LoginView: View {
    private let positioning = Positioning()

    @Environment(\.dismiss) private var dismiss

    @State private var selectedRegion = regions[0]
    @State private var apiKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isLoggedIn = false
    @State private var showAlert = false

    enum Field {
        case apiKey, email, password
    }
    @FocusState private var focusedField: Field?

    let confirm: ButtonRole = {
        if #available(iOS 26.0, *) {
            return .confirm
        } else {
            return .cancel
        }
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Authentication") {
                    if isLoggedIn {
                        Label(
                            "You are signed in.",
                            systemImage: "checkmark.circle"
                        )
                        .padding(8)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(.rect(cornerRadius: 8))
                    } else {
                        Label(
                            "You need to sign in.",
                            systemImage: "info.circle"
                        )
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(.rect(cornerRadius: 8))
                    }

                    Picker("Region", selection: $selectedRegion) {
                        ForEach(regions, id: \.name) { region in
                            Text(region.name).tag(region)
                        }
                    }.pickerStyle(.segmented)

                    LabeledContent {
                        SensitiveField(label: "API Key", text: $apiKey)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .apiKey)
                    } label: {
                        Label("", systemImage: "key")
                    }
                    .onTapGesture {
                        focusedField = .apiKey
                    }
                    .onSubmit {
                        focusedField = .email
                    }

                    LabeledContent {
                        TextField("Email", text: $email)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                    } label: {
                        Label("", systemImage: "envelope")
                    }
                    .onTapGesture {
                        focusedField = .email
                    }
                    .onSubmit {
                        focusedField = .password
                    }

                    LabeledContent {
                        SensitiveField(label: "Password", text: $password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                    } label: {
                        Label("", systemImage: "lock")
                    }
                    .onTapGesture {
                        focusedField = .password
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
                .alert(
                    isLoggedIn ? "Success" : "Something Went Wrong",
                    isPresented: $showAlert
                ) {
                    Button("OK", role: isLoggedIn ? confirm : .cancel) {}
                        .background(.blue)
                        .foregroundStyle(.white)
                } message: {
                    Text(
                        isLoggedIn
                            ? "You are now signed in and can now proceed with the demo."
                            : "We could not sign you in. Please check your internet connection, chosen region, and login credentials, and try again."
                    )
                }

                Section("Device") {
                    Group {
                        Button {
                            Task {
                                isLoading = true
                                await positioning.registerDevice(
                                    apiKey: apiKey,
                                    userID: "northstar-demo"
                                )
                                isLoading = false
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Register")
                            }
                        }

                        Button {
                            Task {
                                await positioning.checkDeviceStatus(
                                    apiKey: apiKey
                                )
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Check Status")
                            }
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
            }
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left").onTapGesture { dismiss() }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Image(systemName: "chevron.down")
                        .padding()
                        .onTapGesture {
                            focusedField = nil
                        }
                }
            }
        }
    }

    // MARK: Views

    private struct SensitiveField: View {
        let label: String
        @Binding var text: String

        @State var hideInput = true
        @FocusState var isFocused: Bool

        var body: some View {
            HStack {
                ZStack {
                    if hideInput {
                        SecureField(label, text: $text)
                            .textContentType(.password)
                            .focused($isFocused)
                    } else {
                        TextField(label, text: $text)
                            .autocorrectionDisabled()
                            .keyboardType(.alphabet)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .focused($isFocused)
                    }
                }
                if !text.isEmpty {
                    Image(systemName: hideInput ? "eye" : "eye.slash")
                        .onTapGesture {
                            hideInput.toggle()
                            DispatchQueue.main.async {
                                isFocused = true
                            }
                        }
                        .foregroundStyle(.black)
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
        showAlert = true
    }

    private func logIn() async {
        let url = URL(
            string:
                "https://analytics\(selectedRegion.modifier).walkbase.com/api/j/login"
        )!
        let parameters: Parameters = ["username": email, "password": password]
        let headers: HTTPHeaders = ["W-SDK-Client-API-Key": apiKey]

        let response = await AF.request(
            url,
            method: .post,
            parameters: parameters,
            headers: headers,
        ).validate().serializingData().response

        if case .success = response.result {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }
}

// MARK: Structs

private struct Region: Hashable {
    let modifier: String
    let name: String
}

// MARK: Preview

#Preview {
    LoginView()
}
