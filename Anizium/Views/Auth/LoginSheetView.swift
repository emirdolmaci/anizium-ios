import SwiftUI

public struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var auth = AuthManager.shared

    @State private var isRegisterMode = false
    @State private var username = AuthManager.shared.savedUsername
    @State private var email = ""
    @State private var password = AuthManager.shared.savedPassword
    @State private var confirmPassword = ""
    @State private var rememberDevice = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Logo / Header
                        VStack(spacing: 8) {
                            Text("ANIZIUM")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.red)

                            Text(isRegisterMode ? "Yeni Hesap Oluştur" : "Hesabına Giriş Yap")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 24)

                        // Segment Picker
                        Picker("Mod", selection: $isRegisterMode) {
                            Text("Giriş Yap").tag(false)
                            Text("Kayıt Ol").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 24)

                        // Inputs
                        VStack(spacing: 12) {
                            if isRegisterMode {
                                customTextField(
                                    icon: "person",
                                    placeholder: "Kullanıcı Adı",
                                    text: $username,
                                    isSecure: false
                                )

                                customTextField(
                                    icon: "envelope",
                                    placeholder: "E-Posta",
                                    text: $email,
                                    isSecure: false,
                                    keyboardType: .emailAddress
                                )
                            } else {
                                customTextField(
                                    icon: "person",
                                    placeholder: "Kullanıcı Adı veya E-Posta",
                                    text: $username,
                                    isSecure: false
                                )
                            }

                            customTextField(
                                icon: "lock",
                                placeholder: "Şifre",
                                text: $password,
                                isSecure: true
                            )

                            if isRegisterMode {
                                customTextField(
                                    icon: "lock.shield",
                                    placeholder: "Şifre Tekrar",
                                    text: $confirmPassword,
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        // Remember Device Toggle
                        Toggle(isOn: $rememberDevice) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                Text("Bu Cihazı Hatırla (Otomatik Giriş)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .tint(.red)
                        .padding(.horizontal, 24)

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Submit Button
                        Button(action: handleAction) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isRegisterMode ? "Kayıt Ol" : "Giriş Yap")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    @ViewBuilder
    private func customTextField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                TextField(placeholder, text: text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(keyboardType)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color(hex: "1A1A20"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func handleAction() {
        errorMessage = nil

        if isRegisterMode {
            guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
                  !email.trimmingCharacters(in: .whitespaces).isEmpty,
                  !password.isEmpty else {
                errorMessage = "Lütfen tüm alanları doldurun."
                return
            }
            guard password == confirmPassword else {
                errorMessage = "Şifreler uyuşmuyor."
                return
            }
            isLoading = true
            Task {
                do {
                    let res = try await AniziumAPI.shared.register(
                        username: username.trimmingCharacters(in: .whitespaces),
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password
                    )
                    await MainActor.run {
                        isLoading = false
                        if let session = res.session, !session.isEmpty {
                            auth.login(
                                token: session,
                                username: username.trimmingCharacters(in: .whitespaces),
                                password: password,
                                remember: true
                            )
                            dismiss()
                        } else {
                            errorMessage = res.msg ?? res.message ?? "Kayıt başarılı, lütfen giriş yapın."
                            isRegisterMode = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
                  !password.isEmpty else {
                errorMessage = "Kullanıcı adı ve şifre girin."
                return
            }
            isLoading = true
            let userVal = username.trimmingCharacters(in: .whitespaces)
            let passVal = password
            Task {
                do {
                    let res = try await AniziumAPI.shared.login(
                        value: userVal,
                        password: passVal
                    )
                    await MainActor.run {
                        isLoading = false
                        if let session = res.session, !session.isEmpty {
                            auth.login(
                                token: session,
                                username: userVal,
                                password: passVal,
                                remember: rememberDevice
                            )
                            dismiss()
                        } else {
                            errorMessage = res.msg ?? res.message ?? "Giriş başarısız."
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
