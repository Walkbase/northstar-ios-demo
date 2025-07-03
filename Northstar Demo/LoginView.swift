import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    
    @FocusState private var isFocused: Bool

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
                SensitiveField(label: "API Key", text: $apiKey)
                    .focused($isFocused)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.none)
                    .focused($isFocused)
                SensitiveField(label: "Password", text: $password)
                    .focused($isFocused)
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
            case secure
            case text
        }
        @FocusState var focusedField: Field?

        var body: some View {
            HStack {
                ZStack {
                    SecureField(label, text: $text)
                        .opacity(hideInput ? 1 : 0)
                        .focused($focusedField, equals: .secure)
                    TextField(label, text: $text)
                        .autocorrectionDisabled()
                        .keyboardType(.alphabet)
                        .textInputAutocapitalization(.none)
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
                }
            }
        }
    }

    private func signIn() {
        isFocused = false
        showAlert = true
    }
}

#Preview {
    LoginView()
}
