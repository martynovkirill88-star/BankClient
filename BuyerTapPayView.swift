import SwiftUI
import LocalAuthentication
import AudioToolbox

// MARK: - Buyer Tap-To-Pay Screen (NameDrop Contact + Apple NFC)
struct BuyerTapPayView: View {
    @Environment(\.dismiss) private var dismiss
    let buyer: User
    var onPaymentCompleted: ((Double) -> Void)?
    
    @StateObject private var tapManager = TapPaymentManager.shared
    
    @State private var foundSession: TerminalSession? = nil
    @State private var isLoadingDetails: Bool = false
    @State private var isPaying: Bool = false
    @State private var isPaidSuccess: Bool = false
    @State private var errorMessage: String = ""
    
    // Wave animation for radar
    @State private var waveScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                if isPaidSuccess {
                    successReceiptView
                } else if let session = foundSession {
                    confirmPaymentView(session: session)
                } else {
                    waitingForTouchRadarView
                }
            }
            .navigationTitle("Оплата касанием")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPaidSuccess ? "Готово" : "Отмена") {
                        tapManager.stopAll()
                        dismiss()
                    }
                    .foregroundColor(BankTheme.mint)
                }
            }
            .onAppear {
                startScanning()
            }
            .onDisappear {
                tapManager.stopAll()
            }
        }
    }
    
    // MARK: - View 1: Radar / Waiting for Touch
    private var waitingForTouchRadarView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 30)
            
            // NameDrop animated concentric glow rings (Centered strictly with anchor: .center for iOS 16/17 compatibility)
            ZStack(alignment: .center) {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [BankTheme.mint.opacity(0.8), BankTheme.cyan.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140 + CGFloat(i * 55), height: 140 + CGFloat(i * 55))
                        .scaleEffect(waveScale, anchor: .center)
                        .opacity(max(0.05, 0.7 - Double(i) * 0.2))
                        .animation(
                            .easeInOut(duration: 1.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.25),
                            value: waveScale
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(BankTheme.bgCard)
                        .frame(width: 120, height: 120)
                        .overlay(Circle().stroke(BankTheme.mint, lineWidth: 2))
                        .shadow(color: BankTheme.mint.opacity(0.4), radius: 20)
                    
                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(BankTheme.mint)
                }
            }
            .frame(width: 280, height: 280, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear { waveScale = 1.15 }
            
            VStack(spacing: 10) {
                Text("Приложите iPhone к терминалу")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                
                Text("Поднесите верхний край вашего iPhone вплотную к телефону продавца, как в NameDrop.")
                    .font(.system(size: 13))
                    .foregroundColor(BankTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BankTheme.coral)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Current balance info
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(BankTheme.mint)
                Text("Доступно для оплаты:")
                    .foregroundColor(BankTheme.textMuted)
                Text(buyer.formattedBalance)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(BankTheme.bgCard)
            .cornerRadius(12)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - View 2: Confirm Payment
    private func confirmPaymentView(session: TerminalSession) -> some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 10)
            
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.18))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(BankTheme.mint)
            }
            
            VStack(spacing: 8) {
                Text("Терминал обнаружен!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BankTheme.mint)
                
                Text(session.merchant_name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let d = session.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 13))
                        .foregroundColor(BankTheme.textMuted)
                }
                
                Text("\(Int(session.amount)) ₽")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
            
            Divider().background(BankTheme.border)
                .padding(.horizontal, 24)
            
            // Balance check row
            HStack {
                Text("Ваш баланс после оплаты:")
                    .foregroundColor(BankTheme.textMuted)
                Spacer()
                let after = buyer.balance - session.amount
                Text("\(Int(max(0, after))) ₽")
                    .fontWeight(.bold)
                    .foregroundColor(after >= 0 ? BankTheme.mint : BankTheme.coral)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 24)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BankTheme.coral)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            Button(action: {
                authenticateAndPay(session: session)
            }) {
                HStack(spacing: 10) {
                    if isPaying {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 20, weight: .bold))
                        Text("Оплатить \(Int(session.amount)) ₽ через Face ID")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buyer.balance >= session.amount ? BankTheme.mint : Color.gray.opacity(0.4))
                .cornerRadius(18)
                .shadow(color: BankTheme.mint.opacity(0.3), radius: 10, y: 4)
            }
            .disabled(buyer.balance < session.amount || isPaying)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - View 3: Success Receipt
    private var successReceiptView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.18))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(BankTheme.mint)
            }
            
            VStack(spacing: 8) {
                Text("Оплата успешно выполнена!")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                
                if let s = foundSession {
                    Text("-\(Int(s.amount)) ₽")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("В пользу: \(s.merchant_name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BankTheme.mint)
                }
            }
            
            Spacer()
            
            Button("Закрыть") {
                dismiss()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BankTheme.mint)
            .cornerRadius(18)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Actions
    private func startScanning() {
        errorMessage = ""
        tapManager.startBuyerTouchSession { sessionId in
            // Touch contact detected! Fetch session details
            Task {
                await MainActor.run { isLoadingDetails = true }
                do {
                    let session = try await APIService.shared.getTerminalSession(sessionId: sessionId)
                    await MainActor.run {
                        self.foundSession = session
                        self.isLoadingDetails = false
                        // Automatically prompt Face ID confirmation
                        self.authenticateAndPay(session: session)
                    }
                } catch {
                    await MainActor.run {
                        self.isLoadingDetails = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func authenticateAndPay(session: TerminalSession) {
        guard buyer.balance >= session.amount else {
            errorMessage = "Недостаточно средств для оплаты"
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Подтвердите оплату \(Int(session.amount)) ₽ в пользу \(session.merchant_name)"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.executePayment(session: session)
                    }
                }
            }
        } else {
            // Biometrics not available -> pay directly
            executePayment(session: session)
        }
    }
    
    private func executePayment(session: TerminalSession) {
        isPaying = true
        errorMessage = ""
        
        Task {
            do {
                let (_, newBal) = try await APIService.shared.payTerminalSession(sessionId: session.id, buyerId: buyer.id)
                await MainActor.run {
                    self.isPaying = false
                    self.isPaidSuccess = true
                    
                    // Authentic Apple Pay success chime (1407 = payment_success.caf) and haptic
                    AudioServicesPlaySystemSound(1407)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onPaymentCompleted?(newBal)
                }
            } catch {
                await MainActor.run {
                    self.isPaying = false
                    self.errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}
