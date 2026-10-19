import SwiftUI
import LocalAuthentication

struct PinLockView: View {
    @Binding var currentUser: User?
    @Binding var showWelcomeScreen: Bool
    
    @AppStorage("bank_user_phone") private var savedPhone: String = ""
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
                // Top Bar with Settings
                HStack {
                    Spacer()
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(BankTheme.textMuted)
                            .padding(12)
                            .background(BankTheme.bgCard)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                
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
                
                // Numeric Keypad with Liquid Glass Buttons
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
                                Button(action: { handleKeypad(key) }) {
                                    Group {
                                        if key == "DEL" {
                                            Image(systemName: "delete.left.fill")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundColor(BankTheme.textMuted)
                                        } else {
                                            Text(key)
                                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                                .foregroundColor(key == "C" ? BankTheme.textMuted : .white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .glassEffect(cornerRadius: 32)
                                }
                                .frame(width: 76, height: 76)
                                .buttonStyle(GlassScaleButtonStyle())
                                .disabled(isLoading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Liquid Glass Face ID Button
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
                    .glassEffect(cornerRadius: 18)
                }
                .buttonStyle(GlassScaleButtonStyle())
                .padding(.horizontal, 32)
                
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
            RegisterSheetView(onSuccess: { registeredUser in
                savedPhone = registeredUser.phone ?? ""
                currentUser = registeredUser
                showWelcomeScreen = true
            })
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
        
        isLoading = true
        errorMessage = ""
        
        do {
            let user = try await APIService.shared.loginWithPin(phone: savedPhone, pin: pinBuffer)
            await MainActor.run {
                isLoading = false
                currentUser = user
                showWelcomeScreen = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                shakePin()
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
                        // If phone is saved, fetch latest real profile directly
                        if !savedPhone.isEmpty {
                            Task {
                                do {
                                    let user = try await APIService.shared.fetchUserByPhone(phone: savedPhone)
                                    await MainActor.run {
                                        currentUser = user
                                        showWelcomeScreen = true
                                    }
                                } catch {
                                    await MainActor.run {
                                        errorMessage = "Не удалось загрузить профиль (\(error.localizedDescription))"
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

// MARK: - Server Settings Sheet
struct ServerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("server_base_url") private var baseURL: String = "http://192.168.1.247:8000"
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Адрес сервера API")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                        
                        TextField("http://192.168.1.247:8000", text: $baseURL)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(BankTheme.bgCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("Укажите IP-адрес компьютера в Wi-Fi сети или домен вашего сервера.")
                            .font(.system(size: 12))
                            .foregroundColor(BankTheme.textMuted)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Сохранить и закрыть") {
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
            .navigationTitle("Настройки сервера")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Registration Sheet
struct RegisterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var onSuccess: (User) -> Void
    
    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var phone: String = "+7"
    @State private var pin1: String = ""
    @State private var pin2: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        formField(title: "ИМЯ", placeholder: "Кирилл", text: $name)
                        formField(title: "ФАМИЛИЯ", placeholder: "Смирнов", text: $surname)
                        formField(title: "НОМЕР ТЕЛЕФОНА", placeholder: "+7 999 123-45-67", text: $phone)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ПИН-КОД (4 ЦИФРЫ)")
                                .font(.system(size: 12, weight: .bold))
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
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(BankTheme.textMuted)
                            SecureField("••••", text: $pin2)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(BankTheme.bgCard)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                .foregroundColor(.white)
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BankTheme.danger)
                        }
                        
                        Button(action: submitRegister) {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Открыть счёт (+1 000 ₽)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BankTheme.mint)
                        .cornerRadius(16)
                        .padding(.top, 10)
                        .disabled(isLoading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
        }
    }
    
    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(BankTheme.textMuted)
            TextField(placeholder, text: text)
                .padding()
                .background(BankTheme.bgCard)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                .foregroundColor(.white)
        }
    }
    
    private func submitRegister() {
        guard !name.isEmpty, !phone.isEmpty else {
            errorMessage = "Заполните имя и телефон"
            return
        }
        guard pin1 == pin2 else {
            errorMessage = "ПИН-коды не совпадают"
            return
        }
        guard pin1.count == 4 else {
            errorMessage = "ПИН-код должен содержать 4 цифры"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let user = try await APIService.shared.register(
                    name: name,
                    surname: surname,
                    phone: phone,
                    pin: pin1
                )
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onSuccess(user)
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

// MARK: - Native Liquid Glass System Modifiers
extension View {
    /// Нативный модификатор Liquid Glass на базе системных материалов SwiftUI (.ultraThinMaterial)
    /// с динамическим преломлением фона, мягкой линзовой границей и световым контуром.
    func glassEffect(cornerRadius: CGFloat = 32) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.65), location: 0.0),
                                .init(color: .white.opacity(0.18), location: 0.35),
                                .init(color: .clear, location: 0.70),
                                .init(color: .white.opacity(0.25), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}

struct GlassScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
