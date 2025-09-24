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
        NavigationStack {
            Form {
                Section("Authentication") {
                    if appData.isLoggedIn {
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

                    Picker("Region", selection: $appData.selectedRegion) {
                        ForEach(appData.regions, id: \.name) { region in
                            Text(region.name).tag(region)
                        }
                    }.pickerStyle(.segmented)

                    LabeledContent {
                        TextField("Email", text: $appData.email)
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
                                    .autocorrectionDisabled()
                                    .keyboardType(.alphabet)
                                    .textInputAutocapitalization(.never)
                                }
                            }
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
                                .foregroundStyle(.black)
                            }
                        }

                    } label: {
                        Label("", systemImage: "lock")
                    }
                    .onTapGesture {
                        focusedField = .password
                    }
                    .onSubmit {
                        focusedField = .apiKey
                    }

                    LabeledContent {
                        TextField("API Key", text: $appData.apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .apiKey)
                    } label: {
                        Label("", systemImage: "key")
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
            .navigationTitle("Sign In")
            .toolbar {
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

    // MARK: Methods

    private func submit() async {
        focusedField = nil
        isLoading = true
        await logIn()
        isLoading = false
    }

    private func logIn() async {
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
