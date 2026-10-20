import SwiftUI

enum TransferStep {
    case input
    case confirm
    case verifying
    case success
}

struct TransferView: View {
    let currentUser: User
    var onTransferCompleted: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Step state
    @State private var currentStep: TransferStep = .input
    
    // Form fields
    @State private var recipientPhone: String = "+7"
    @State private var recipientName: String? = nil
    @State private var isLookingUp: Bool = false
    @State private var amountString: String = ""
    @State private var errorMessage: String = ""
    @State private var showContactsPicker: Bool = false
    
    // Result
    @State private var finalBalance: Double = 0.0
    
    // Verification stage text animation
    @State private var verificationStage: String = "Проверка параметров и лимитов транзакции..."
    
    let quickAmounts = [100, 500, 1000, 3000, 5000]
    
    private var parsedAmount: Double {
        Double(amountString.filter { $0.isNumber }) ?? 0.0
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let num = NSNumber(value: parsedAmount)
        return "\(formatter.string(from: num) ?? "\(Int(parsedAmount))") ₽"
    }
    
    private var recipientDisplayName: String {
        if let name = recipientName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "Клиент RoPay"
    }
    
    private var recipientInitials: String {
        let name = recipientDisplayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let f = parts[0].prefix(1)
            let s = parts[1].prefix(1)
            return "\(f)\(s)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "RP"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                ambientBackground
                
                Group {
                    switch currentStep {
                    case .input:
                        inputView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .confirm:
                        confirmView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .verifying:
                        verifyingView
                            .transition(.opacity)
                    case .success:
                        successView
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
            .navigationTitle(navigationTitleForStep)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep == .input {
                        Button("Отмена") { dismiss() }
                            .foregroundColor(BankTheme.mint)
                    } else if currentStep == .confirm {
                        Button("Назад") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentStep = .input
                            }
                        }
                        .foregroundColor(BankTheme.mint)
                    }
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView { phone, name in
                    recipientPhone = phone
                    recipientName = name
                    lookupRecipient(phone: phone)
                }
            }
        }
    }
    
    private var navigationTitleForStep: String {
        switch currentStep {
        case .input: return "Перевод клиенту"
        case .confirm: return "Сверка данных"
        case .verifying: return "Проверка безопасности"
        case .success: return "Успешный перевод"
        }
    }
    
    // MARK: - Ambient Background
    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [BankTheme.mint.opacity(0.10), Color.clear],
                    center: .center, startRadius: 10, endRadius: 180
                ))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 120, y: -150)
            Circle()
                .fill(RadialGradient(
                    colors: [BankTheme.purple.opacity(0.14), Color.clear],
                    center: .center, startRadius: 10, endRadius: 200
                ))
                .frame(width: 350, height: 350)
                .blur(radius: 60)
                .offset(x: -90, y: 200)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Step 1: Input View
    private var inputView: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Contact Picker Shortcut Button
                if #available(iOS 26.0, *) {
                    Button(action: { showContactsPicker = true }) {
                        contactPickerRowContent
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: { showContactsPicker = true }) {
                        contactPickerRowContent
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                
                // Recipient Phone Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("НОМЕР ТЕЛЕФОНА ПОЛУЧАТЕЛЯ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BankTheme.textMuted)
                    
                    HStack {
                        TextField("+7 999 123-45-67", text: $recipientPhone)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .keyboardType(.phonePad)
                            .onChange(of: recipientPhone) { newValue in
                                lookupRecipient(phone: newValue)
                            }
                        
                        Button(action: { showContactsPicker = true }) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 22))
                                .foregroundColor(BankTheme.mint)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Recipient Verified Pill
                    if isLookingUp {
                        HStack(spacing: 8) {
                            ProgressView().tint(BankTheme.mint)
                            Text("Поиск клиента в RoPay...")
                                .font(.system(size: 13))
                                .foregroundColor(BankTheme.textMuted)
                        }
                        .padding(.top, 4)
                    } else if let name = recipientName {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(BankTheme.mint)
                            Text("Получатель: \(name)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(BankTheme.mint.opacity(0.12))
                        .cornerRadius(12)
                        .padding(.top, 4)
                    }
                }
                
                // Transfer Amount with Liquid Glass
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("СУММА ПЕРЕВОДА")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                        
                        Spacer()
                        
                        Text("Баланс: \(currentUser.formattedBalance)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(BankTheme.mint)
                    }
                    
                    LiquidGlassAmountView(amountString: $amountString)
                }
                
                // Quick Amount Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickAmounts, id: \.self) { amt in
                            quickAmountChip(amt)
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(BankTheme.danger)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BankTheme.danger)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BankTheme.danger.opacity(0.12))
                    .cornerRadius(14)
                }
                
                Spacer(minLength: 20)
                
                // Button: ПРОДОЛЖИТЬ
                if #available(iOS 26.0, *) {
                    Button(action: handleContinueToConfirmation) {
                        HStack(spacing: 8) {
                            Text("Продолжить")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: handleContinueToConfirmation) {
                        HStack(spacing: 8) {
                            Text("Продолжить")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BankTheme.mint)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var contactPickerRowContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BankTheme.purpleGradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 19))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Перевод контактам")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Выбрать из телефонной книги (проверка в RoPay)")
                    .font(.system(size: 12))
                    .foregroundColor(BankTheme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(BankTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    private func quickAmountChip(_ amt: Int) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        amountString = "\(amt)"
                    }
                }) {
                    Text("+\(amt) ₽")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        amountString = "\(amt)"
                    }
                }) {
                    Text("+\(amt) ₽")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Step 2: Confirmation / Verification View
    private var confirmView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header instruction
                VStack(spacing: 6) {
                    Text("Сверка данных перевода")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    Text("Пожалуйста, проверьте реквизиты получателя и сумму перед отправкой")
                        .font(.system(size: 13))
                        .foregroundColor(BankTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 10)
                
                // Main Confirmation Glass Card
                VStack(spacing: 18) {
                    // Recipient Header
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [BankTheme.mint, BankTheme.purple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 54, height: 54)
                            Text(recipientInitials)
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipientDisplayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text(recipientPhone)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BankTheme.textMuted)
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(BankTheme.mint)
                                Text("Клиент RoPay Digital Bank")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(BankTheme.mint)
                            }
                        }
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.12))
                    
                    // Amount Display
                    VStack(spacing: 4) {
                        Text("СУММА К СКАЧИВАНИЮ / ПЕРЕВОДУ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                        Text(formattedAmount)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: BankTheme.mint.opacity(0.35), radius: 14)
                    }
                    .padding(.vertical, 8)
                    
                    Divider().background(Color.white.opacity(0.12))
                    
                    // Transaction Specs Rows
                    VStack(spacing: 12) {
                        detailRow(title: "Счёт списания", value: "Основной счёт (Баланс: \(currentUser.formattedBalance))")
                        detailRow(title: "Комиссия за перевод", value: "0 ₽ (Бесплатно)", valueColor: BankTheme.mint)
                        detailRow(title: "Срок зачисления", value: "Мгновенно")
                        detailRow(title: "Защита операции", value: "Антиспам-мониторинг RoPay", valueColor: BankTheme.mint)
                    }
                }
                .padding(22)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                
                if !errorMessage.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.slash.fill")
                            .foregroundColor(BankTheme.danger)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BankTheme.danger)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BankTheme.danger.opacity(0.12))
                    .cornerRadius(14)
                }
                
                Spacer(minLength: 16)
                
                // Confirm & Back Buttons
                VStack(spacing: 12) {
                    if #available(iOS 26.0, *) {
                        Button(action: executeTransferWithAntiSpam) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16))
                                Text("Подтвердить перевод")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.glass)
                    } else {
                        Button(action: executeTransferWithAntiSpam) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16))
                                Text("Подтвердить перевод")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(BankTheme.mint)
                            .cornerRadius(16)
                        }
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .input
                        }
                    }) {
                        Text("Изменить данные")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BankTheme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func detailRow(title: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(BankTheme.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Step 3: Verifying & Anti-Spam Check View (Lottie Animated Loader)
    private var verifyingView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // White Lottie Loader from CyPnRwRkl4.json
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        center: .center, startRadius: 10, endRadius: 80
                    ))
                    .frame(width: 170, height: 170)
                
                LottieWhiteLoaderView()
            }
            
            VStack(spacing: 10) {
                Text("Проверка перевода...")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                
                Text("Система безопасности банка проверяет параметры транзакции на спам и подтверждает операцию")
                    .font(.system(size: 14))
                    .foregroundColor(BankTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Realtime Security Status Capsule
            HStack(spacing: 10) {
                ProgressView().tint(BankTheme.mint)
                Text(verificationStage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BankTheme.mint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BankTheme.mint.opacity(0.3), lineWidth: 1)
            )
            
            Spacer()
            
            Text("Пожалуйста, не закрывайте приложение во время верификации")
                .font(.system(size: 12))
                .foregroundColor(BankTheme.textMuted.opacity(0.7))
                .padding(.bottom, 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Step 4: Success View
    private var successView: some View {
        VStack(spacing: 26) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.18))
                    .frame(width: 110, height: 110)
                    .blur(radius: 10)
                Circle()
                    .fill(BankTheme.mint)
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 8) {
                Text("Перевод выполнен!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                Text("Сумма \(formattedAmount) успешно переведена получателю \(recipientDisplayName)")
                    .font(.system(size: 15))
                    .foregroundColor(BankTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 6) {
                Text("Новый баланс счёта:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(BankTheme.textMuted)
                Text("\(Int(finalBalance)) ₽")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(BankTheme.mint)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            Spacer()
            
            Button(action: {
                onTransferCompleted(finalBalance)
                dismiss()
            }) {
                Text("Готово")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(BankTheme.mint)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(20)
    }
    
    // MARK: - Actions & Logic
    private func lookupRecipient(phone: String) {
        guard phone.count >= 8 else {
            recipientName = nil
            return
        }
        
        isLookingUp = true
        Task {
            do {
                let res = try await APIService.shared.lookupPhone(phone: phone)
                await MainActor.run {
                    isLookingUp = false
                    recipientName = res.found ? res.display_name : nil
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    recipientName = nil
                }
            }
        }
    }
    
    private func handleContinueToConfirmation() {
        errorMessage = ""
        let amt = parsedAmount
        guard amt > 0 else {
            errorMessage = "Укажите корректную сумму перевода"
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        guard amt <= currentUser.balance else {
            errorMessage = "Недостаточно средств. Ваш баланс: \(currentUser.formattedBalance)"
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        guard recipientPhone.count >= 8 else {
            errorMessage = "Укажите корректный номер телефона получателя"
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentStep = .confirm
        }
    }
    
    private func executeTransferWithAntiSpam() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = .verifying
            verificationStage = "Проверка параметров и лимитов транзакции..."
        }
        
        // Dynamic progress stages
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                if currentStep == .verifying {
                    verificationStage = "Антиспам-мониторинг и аудит безопасности..."
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                if currentStep == .verifying {
                    verificationStage = "Связь с защищённым сервером app.ropay.site..."
                }
            }
        }
        
        // Execute server request
        let amt = parsedAmount
        Task {
            do {
                let newBal = try await APIService.shared.transferFunds(
                    senderId: currentUser.id,
                    recipientPhone: recipientPhone,
                    amount: amt
                )
                await MainActor.run {
                    finalBalance = newBal
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .success
                    }
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep = .confirm
                    }
                }
            }
        }
    }
}
