import SwiftUI
import LocalAuthentication

struct AdminLoginView: View {
    var onLoginSuccess: () -> Void
    
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        ZStack {
            AdminTheme.bgDark.ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [AdminTheme.gold.opacity(0.18), Color.clear],
                    center: .center, startRadius: 10, endRadius: 200
                ))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(y: -120)
            
            VStack(spacing: 24) {
                Spacer()
                
                // Admin Logo
                ZStack {
                    Circle()
                        .fill(AdminTheme.gold.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 42))
                        .foregroundColor(AdminTheme.gold)
                }
                .overlay(Circle().stroke(AdminTheme.gold.opacity(0.4), lineWidth: 2))
                
                VStack(spacing: 6) {
                    Text("RoPay Admin")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("Панель управления банком")
                        .font(.system(size: 14))
                        .foregroundColor(AdminTheme.textSecondary)
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("ПАРОЛЬ АДМИНИСТРАТОРА")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AdminTheme.textSecondary)
                    
                    SecureField("Введите пароль", text: $password)
                        .padding()
                        .background(AdminTheme.bgCard)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                }
                .padding(.horizontal, 32)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AdminTheme.danger)
                        .padding(.horizontal, 32)
                }
                
                // Login Button
                Button(action: doLogin) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "lock.open.fill")
                            Text("Войти в систему")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AdminTheme.gold)
                    .cornerRadius(16)
                }
                .disabled(isLoading || password.isEmpty)
                .padding(.horizontal, 32)
                
                // Face ID Button
                Button(action: authFaceID) {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Вход по Face ID")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AdminTheme.mint)
                }
                .padding(.top, 4)
                
                Spacer()
                
                Text("Сервер: app.ropay.site • RoPay Core v1.0")
                    .font(.system(size: 11))
                    .foregroundColor(AdminTheme.textSecondary.opacity(0.6))
                    .padding(.bottom, 20)
            }
        }
    }
    
    private func doLogin() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                _ = try await AdminAPIService.shared.login(password: password)
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onLoginSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func authFaceID() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Вход в панель управления RoPay") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onLoginSuccess()
                    }
                }
            }
        }
    }
}
