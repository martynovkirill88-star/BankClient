import SwiftUI
import LocalAuthentication

struct PinLockView: View {
    @Binding var currentUser: User?
    @Binding var showWelcomeScreen: Bool
    
    @AppStorage("bank_user_phone") private var savedPhone: String = ""
    @AppStorage("bank_cached_pin") private var cachedPin: String = ""
    @AppStorage("bank_cached_user_json") private var cachedUserJson: String = ""
    @State private var pinBuffer: String = ""
    @State private var isError: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    @State private var showRegisterSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showSwitchPhoneAlert: Bool = false
    @State private var tempPhoneInput: String = ""
    
    var body: some View {
        ZStack {
            BankTheme.bgDark.ignoresSafeArea()
            
            // Ambient Fluid Light Underlay (gives liquid glass real light to refract)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [BankTheme.mint.opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 50)
                    .offset(x: -80, y: -160)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [BankTheme.purple.opacity(0.24), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 220
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 65)
                    .offset(x: 90, y: 140)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                Spacer().frame(height: 10)
                
                Spacer()
                
                // Bank Icon & Greeting Header
                VStack(spacing: 12) {
                    if let img = UIImage(named: "RoPayLogo") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: BankTheme.mint.opacity(0.3), radius: 12)
                    } else {
                        ZStack {
                            Circle()
                                .fill(BankTheme.mint.opacity(0.12))
                                .frame(width: 72, height: 72)
                            
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 32))
                                .foregroundColor(BankTheme.mint)
                        }
                    }
                    
                    Text("RoPay")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                    
                    if !savedPhone.isEmpty {
                        Text(savedPhone)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BankTheme.mint)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(BankTheme.bgCard)
                            .cornerRadius(12)
                    } else {
                        Text("Введите ПИН-код или зарегистрируйтесь")
                            .font(.system(size: 14))
                            .foregroundColor(BankTheme.textMuted)
                    }
                }
                
                // 4 PIN Dots
                HStack(spacing: 16) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < pinBuffer.count ? BankTheme.mint : BankTheme.bgCardSubtle)
                            .overlay(
                                Circle()
                                    .stroke(isError ? BankTheme.danger : (index < pinBuffer.count ? BankTheme.mint : BankTheme.border), lineWidth: 2)
                            )
                            .frame(width: 18, height: 18)
                            .scaleEffect(index < pinBuffer.count ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pinBuffer.count)
                    }
                }
                .padding(.vertical, 10)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(BankTheme.danger)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Numeric Keypad — iOS 26+ Liquid Glass / Fallback
                VStack(spacing: 16) {
                    let rows = [
                        ["1", "2", "3"],
                        ["4", "5", "6"],
                        ["7", "8", "9"],
                        ["C", "0", "DEL"]
                    ]
                    
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 18) {
                            ForEach(row, id: \.self) { key in
                                if #available(iOS 26.0, *) {
                                    // ✅ iOS 26+: нативный системный эффект Liquid Glass
                                    Button(action: { handleKeypad(key) }) {
                                        PinKeyLabel(key: key)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                    .frame(width: 76, height: 76)
                                    .buttonStyle(.glass)
                                    .disabled(isLoading)
                                } else {
                                    // Fallback для iOS < 26
                                    Button(action: { handleKeypad(key) }) {
                                        PinKeyLabel(key: key)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(
                                                .ultraThinMaterial,
                                                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                                            )
                                    }
                                    .frame(width: 76, height: 76)
                                    .buttonStyle(GlassScaleButtonStyle())
                                    .disabled(isLoading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Face ID Button — iOS 26+ Liquid Glass / Fallback
                if #available(iOS 26.0, *) {
                    Button(action: authenticateWithBiometrics) {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 22, weight: .bold))
                            Text("Войти по Face ID")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .padding(.horizontal, 32)
                } else {
                    Button(action: authenticateWithBiometrics) {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                            Text("Войти по Face ID")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                    .buttonStyle(GlassScaleButtonStyle())
                    .padding(.horizontal, 32)
                }
                
                // Footer Links
                HStack(spacing: 24) {
                    Button("Регистрация") {
                        showRegisterSheet = true
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BankTheme.mint)
                    
                    Button("Сменить номер") {
                        tempPhoneInput = savedPhone
                        showSwitchPhoneAlert = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BankTheme.textMuted)
                }
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showRegisterSheet) {
            RegisterSheetView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            ServerSettingsSheet()
        }
        .alert("Сменить номер телефона", isPresented: $showSwitchPhoneAlert) {
            TextField("+7 999 123-45-67", text: $tempPhoneInput)
            Button("Сохранить") {
                savedPhone = tempPhoneInput.trimmingCharacters(in: .whitespacesAndNewlines)
                pinBuffer = ""
                errorMessage = ""
            }
            Button("Отмена", role: .cancel) {}
        }
    }
    
    // MARK: - Keypad Handling
    private func handleKeypad(_ key: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if key == "C" {
            pinBuffer = ""
            errorMessage = ""
            isError = false
        } else if key == "DEL" {
            if !pinBuffer.isEmpty {
                pinBuffer.removeLast()
            }
        } else {
            if pinBuffer.count < 4 {
                pinBuffer.append(key)
                if pinBuffer.count == 4 {
                    Task {
                        await verifyPin()
                    }
                }
            }
        }
    }
    
    // MARK: - Verify PIN
    private func verifyPin() async {
        guard !savedPhone.isEmpty else {
            errorMessage = "Сначала зарегистрируйтесь или укажите номер"
            shakePin()
            return
        }
        
        let enteredPin = pinBuffer
        
        // 1. Instant offline unlock if cached PIN matches
        if !cachedPin.isEmpty && cachedPin == enteredPin,
           let data = cachedUserJson.data(using: .utf8),
           let localUser = try? JSONDecoder().decode(User.self, from: data) {
            await MainActor.run {
                self.currentUser = localUser
                self.showWelcomeScreen = true
                self.pinBuffer = ""
                self.isLoading = false
            }
            
            // Background sync fresh data from server
            Task {
                if let freshUser = try? await APIService.shared.loginWithPin(phone: savedPhone, pin: enteredPin) {
                    await MainActor.run {
                        self.currentUser = freshUser
                        if let encoded = try? JSONEncoder().encode(freshUser),
                           let jsonStr = String(data: encoded, encoding: .utf8) {
                            self.cachedUserJson = jsonStr
                        }
                    }
                }
            }
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let user = try await APIService.shared.loginWithPin(phone: savedPhone, pin: enteredPin)
            await MainActor.run {
                self.isLoading = false
                self.cachedPin = enteredPin
                if let encoded = try? JSONEncoder().encode(user),
                   let jsonStr = String(data: encoded, encoding: .utf8) {
                    self.cachedUserJson = jsonStr
                }
                self.currentUser = user
                self.showWelcomeScreen = true
                self.pinBuffer = ""
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.shakePin()
            }
        }
    }
    
    // MARK: - Native iOS Face ID
    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Авторизация в Клиент Банк"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        // If phone is saved, fetch or use cached profile
                        if !savedPhone.isEmpty {
                            if let data = cachedUserJson.data(using: .utf8),
                               let localUser = try? JSONDecoder().decode(User.self, from: data) {
                                currentUser = localUser
                                showWelcomeScreen = true
                            }
                            Task {
                                do {
                                    let user = try await APIService.shared.fetchUserByPhone(phone: savedPhone)
                                    await MainActor.run {
                                        currentUser = user
                                        showWelcomeScreen = true
                                        if let encoded = try? JSONEncoder().encode(user),
                                           let jsonStr = String(data: encoded, encoding: .utf8) {
                                            cachedUserJson = jsonStr
                                        }
                                    }
                                } catch {
                                    if currentUser == nil {
                                        await MainActor.run {
                                            errorMessage = "Не удалось загрузить профиль (\(error.localizedDescription))"
                                        }
                                    }
                                }
                            }
                        } else {
                            showRegisterSheet = true
                        }
                    }
                }
            }
        } else {
            errorMessage = "Face ID недоступен на этом устройстве"
        }
    }
    
    private func shakePin() {
        isError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isError = false
            pinBuffer = ""
        }
    }
}

// MARK: - Server Settings Sheet (Read-Only)
struct ServerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сервер RoPay (Защищённое подключение)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                        
                        HStack {
                            Circle().fill(BankTheme.mint).frame(width: 8, height: 8)
                            Text("https://app.ropay.site")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BankTheme.bgCard)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                        
                        Text("Адрес сервера зафиксирован на защищённом домене банка RoPay.")
                            .font(.system(size: 12))
                            .foregroundColor(BankTheme.textMuted)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(BankTheme.mint)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.top, 24)
            }
            .navigationTitle("Сервер банка")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Registration Sheet (Application for Opening Bank Account)
struct RegisterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var phone: String = "+7"
    @State private var pin1: String = ""
    @State private var pin2: String = ""
    @State private var telegram: String = ""
    
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header info card matching user instruction
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "globe.europe.africa.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(BankTheme.mint)
                                Text("ОТКРЫТИЕ СЧЁТА")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(BankTheme.mint)
                            }
                            
                            Text("Регистрация доступна на нашем веб-сайте ropay.site. Оставьте заявку, чтобы открыть счет в банке RoPay:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        
                        // Form fields
                        VStack(spacing: 16) {
                            formField(title: "ИМЯ В ПРИЛОЖЕНИИ", placeholder: "Кирилл", text: $name)
                            formField(title: "ФАМИЛИЯ В ПРИЛОЖЕНИИ", placeholder: "Мартынов", text: $surname)
                            
                            // Phone field with note
                            VStack(alignment: .leading, spacing: 6) {
                                Text("НОМЕР ТЕЛЕФОНА")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                
                                TextField("+7 999 123-45-67", text: $phone)
                                    .keyboardType(.phonePad)
                                    .padding()
                                    .background(BankTheme.bgCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                    .foregroundColor(.white)
                                
                                Text("Этот номер телефона будет использован для переводов")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(BankTheme.mint)
                                    .padding(.leading, 2)
                            }
                            
                            // PIN code
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ПРИДУМАЙТЕ ПИН-КОД (4 ЦИФРЫ)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                SecureField("••••", text: $pin1)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(BankTheme.bgCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ПОВТОРИТЕ ПИН-КОД")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                SecureField("••••", text: $pin2)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(BankTheme.bgCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                    .foregroundColor(.white)
                            }
                            
                            // Telegram username
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ЮЗЕРНЕЙМ В TELEGRAM")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                
                                TextField("@username", text: $telegram)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding()
                                    .background(BankTheme.bgCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                    .foregroundColor(.white)
                                
                                Text("Чтобы мы могли связаться с вами после рассмотрения заявки")
                                    .font(.system(size: 11))
                                    .foregroundColor(BankTheme.textMuted)
                                    .padding(.leading, 2)
                            }
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BankTheme.danger)
                                .padding(.horizontal)
                        }
                        
                        // Submit button
                        if #available(iOS 26.0, *) {
                            Button(action: submitApplication) {
                                HStack {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("Оставить заявку")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glass)
                            .disabled(isLoading)
                            .padding(.top, 8)
                        } else {
                            Button(action: submitApplication) {
                                HStack {
                                    if isLoading {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("Оставить заявку")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(BankTheme.mint)
                                .cornerRadius(16)
                            }
                            .disabled(isLoading)
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Заявка на открытие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
            .alert("Заявка принята!", isPresented: $showSuccessAlert) {
                Button("Понятно", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(BankTheme.textMuted)
            TextField(placeholder, text: text)
                .padding()
                .background(BankTheme.bgCard)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                .foregroundColor(.white)
        }
    }
    
    private func submitApplication() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTg = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanName.isEmpty else {
            errorMessage = "Укажите ваше имя"
            return
        }
        guard cleanPhone.count >= 10 else {
            errorMessage = "Укажите корректный номер телефона"
            return
        }
        guard pin1 == pin2 else {
            errorMessage = "ПИН-коды не совпадают"
            return
        }
        guard pin1.count == 4 && pin1.allSatisfy({ $0.isNumber }) else {
            errorMessage = "ПИН-код должен содержать ровно 4 цифры"
            return
        }
        guard !cleanTg.isEmpty else {
            errorMessage = "Укажите юзернейм в Telegram для связи"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let res = try await APIService.shared.submitApplication(
                    name: cleanName,
                    surname: cleanSurname,
                    phone: cleanPhone,
                    pin: pin1,
                    telegram: cleanTg
                )
                await MainActor.run {
                    isLoading = false
                    successMessage = res.message ?? "Ваша заявка успешно отправлена! Мы свяжемся с вами в Telegram после рассмотрения."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showSuccessAlert = true
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
}


// MARK: - Вспомогательный ярлык для кнопки ПИН-пада
struct PinKeyLabel: View {
    let key: String
    
    var body: some View {
        Group {
            if key == "DEL" {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.secondary)
            } else {
                Text(key)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(key == "C" ? .secondary : .white)
            }
        }
    }
}

// MARK: - Fallback Button Style для iOS < 26
struct GlassScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}