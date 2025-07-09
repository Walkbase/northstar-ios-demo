import SwiftUI

private let regions = [
    Region(modifier: "", name: "EU"),
    Region(modifier: "-uk", name: "UK"),
    Region(modifier: "-us", name: "US"),
    Region(modifier: "-dev", name: "Dev"),
]

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRegion = regions[0]
    @State private var apiKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false

    enum Field {
        case apiKey, email, password
    }
    @FocusState private var focusedField: Field?

    let buttonRole: ButtonRole = {
        if #available(iOS 26.0, *) {
            return .confirm
        } else {
            return .cancel
        }
    }()

    var body: some View {
        NavigationStack {
            Form {
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
                    signIn()
                }

                Button("Sign in") {
                    signIn()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .fontWeight(.bold)
            }
            .navigationTitle("Authentication")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left")
                        .onTapGesture {
                            dismiss()
                        }
                }
            }
            .onAppear {
                focusedField = .apiKey
            }
            .alert("Success", isPresented: $showAlert) {
                Button("OK", role: buttonRole) {
                    dismiss()
                }
                .background(.blue)
                .foregroundStyle(.white)
            } message: {
                Text("You are now signed in and can now proceed with the demo.")
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

    private func signIn() {
        focusedField = nil
        showAlert = true
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
