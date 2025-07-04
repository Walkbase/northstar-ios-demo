import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("Setup")
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

    private struct SensitiveField: View {
        let label: String
        @Binding var text: String

        @State var hideInput = true

        enum Field {
            case secure, text
        }
        @FocusState var focusedField: Field?

        var body: some View {
            HStack {
                ZStack {
                    SecureField(label, text: $text)
                        .textContentType(.password)
                        .opacity(hideInput ? 1 : 0)
                        .focused($focusedField, equals: .secure)
                    TextField(label, text: $text)
                        .autocorrectionDisabled()
                        .keyboardType(.alphabet)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .opacity(hideInput ? 0 : 1)
                        .focused($focusedField, equals: .text)
                }
                if !text.isEmpty {
                    Image(systemName: hideInput ? "eye" : "eye.slash")
                        .onTapGesture {
                            hideInput.toggle()
                            focusedField =
                                focusedField == .secure ? .text : .secure
                        }
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private func signIn() {
        focusedField = nil
        showAlert = true
    }
}

#Preview {
    LoginView()
}
