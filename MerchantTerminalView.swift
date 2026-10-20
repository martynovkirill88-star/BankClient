import SwiftUI
import AudioToolbox

// MARK: - POS Terminal View for Business Profiles
struct MerchantTerminalView: View {
    @Environment(\.dismiss) private var dismiss
    let merchant: User
    var onPaymentReceived: ((Double) -> Void)?
    
    @StateObject private var tapManager = TapPaymentManager.shared
    
    @State private var amountString: String = "0"
    @State private var description: String = ""
    @State private var isCreatingSession: Bool = false
    @State private var currentSession: TerminalSession? = nil
    @State private var isPaidSuccess: Bool = false
    @State private var paidBuyerName: String = ""
    @State private var errorMessage: String = ""
    
    // NameDrop liquid wave animation
    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.8
    
    // Polling timer to catch real-time payment from server
    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var enteredAmount: Double {
        Double(amountString) ?? 0.0
    }
    
    var displayBusinessName: String {
        if let b = merchant.business_name, !b.isEmpty { return b }
        return merchant.fullName.isEmpty ? "Терминал RoPay" : "Бизнес: \(merchant.fullName)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                if isPaidSuccess {
                    successReceiptView
                        .transition(.identity)
                } else if let session = currentSession {
                    waitingForCustomerTouchView(session: session)
                        .transition(.identity)
                } else {
                    keypadInputView
                        .transition(.identity)
                }
            }
            .navigationTitle("RoPay Tap: Терминал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(currentSession == nil ? "Закрыть" : "Отмена") {
                        tapManager.stopMerchantTerminal()
                        dismiss()
                    }
                    .foregroundColor(BankTheme.mint)
                }
            }
            .onDisappear {
                tapManager.stopMerchantTerminal()
            }
            .onReceive(pollTimer) { _ in
                guard let session = currentSession, !isPaidSuccess else { return }
                Task {
                    if let updated = try? await APIService.shared.getTerminalSession(sessionId: session.id),
                       updated.status == "paid" {
                        await MainActor.run {
                            self.paidBuyerName = updated.buyer_name ?? "Покупатель"
                            self.isPaidSuccess = true
                            self.tapManager.stopMerchantTerminal()
                            
                            // Authentic Apple Pay success chime (1407 = payment_success.caf) and haptic
                            AudioServicesPlaySystemSound(1407)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onPaymentReceived?(updated.amount)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Screen 1: Numpad Entry
    private var keypadInputView: some View {
        VStack(spacing: 16) {
            // Business Header Card
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BankTheme.gold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(BankTheme.gold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayBusinessName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Бесконтактный приём оплат касанием iPhone")
                        .font(.system(size: 11))
                        .foregroundColor(BankTheme.textMuted)
                }
                Spacer()
                
                Text("БИЗНЕС")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(BankTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BankTheme.gold.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(14)
            .background(BankTheme.bgCard)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(BankTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Amount Display
            VStack(spacing: 4) {
                Text("СУММА К ОПЛАТЕ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(BankTheme.textMuted)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amountString.isEmpty ? "0" : amountString)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("₽")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(BankTheme.mint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            
            // Quick Amount Buttons
            HStack(spacing: 10) {
                quickAddButton("+100 ₽", 100)
                quickAddButton("+500 ₽", 500)
                quickAddButton("+1 000 ₽", 1000)
                quickAddButton("+5 000 ₽", 5000)
            }
            .padding(.horizontal, 20)
            
            // Numpad Grid
            VStack(spacing: 12) {
                ForEach([
                    ["1", "2", "3"],
                    ["4", "5", "6"],
                    ["7", "8", "9"],
                    ["C", "0", "⌫"]
                ], id: \.self) { row in
                    HStack(spacing: 16) {
                        ForEach(row, id: \.self) { key in
                            Button(action: { handleKey(key) }) {
                                Text(key)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(key == "C" ? BankTheme.coral : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(BankTheme.bgCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(BankTheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleTouchButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BankTheme.coral)
            }
            
            Spacer()
            
            // Submit Button
            Button(action: startTerminalSession) {
                HStack(spacing: 10) {
                    if isCreatingSession {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .bold))
                        Text("Принять оплату касанием")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enteredAmount > 0 ? BankTheme.mint : Color.gray.opacity(0.4))
                .cornerRadius(18)
                .shadow(color: enteredAmount > 0 ? BankTheme.mint.opacity(0.3) : .clear, radius: 10, y: 4)
            }
            .disabled(enteredAmount <= 0 || isCreatingSession)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Screen 2: Waiting for Touch (NameDrop Style Radar)
    private func waitingForCustomerTouchView(session: TerminalSession) -> some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            // NameDrop Contact Aura (Locked strictly in center, completely immune to iOS 16/17 origin bugs)
            ZStack(alignment: .center) {
                // Expanding ripple rings from center
                PulseRippleCircle(size: 240, delay: 0.5, gradientColors: [BankTheme.mint.opacity(0.8), BankTheme.purple.opacity(0.4)])
                PulseRippleCircle(size: 190, delay: 0.25, gradientColors: [BankTheme.mint.opacity(0.8), BankTheme.purple.opacity(0.4)])
                PulseRippleCircle(size: 140, delay: 0.0, gradientColors: [BankTheme.mint.opacity(0.8), BankTheme.purple.opacity(0.4)])
                
                // Center Icon with Liquid Glass
                ZStack {
                    Circle()
                        .fill(BankTheme.bgCard)
                        .frame(width: 120, height: 120)
                        .overlay(Circle().stroke(BankTheme.mint, lineWidth: 2))
                        .shadow(color: BankTheme.mint.opacity(0.5), radius: 25)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "wave.3.forward.circle.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(BankTheme.mint)
                        
                        Text("RoPay Tap")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 280, height: 280, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Instructions
            VStack(spacing: 8) {
                Text("\(Int(session.amount)) ₽")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Приложите телефон покупателя")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BankTheme.mint)
                
                Text("Поднесите верхний край или спинку iPhone покупателя вплотную к этому устройству")
                    .font(.system(size: 13))
                    .foregroundColor(BankTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            
            Spacer()
            
            // Cancel button
            Button(action: {
                tapManager.stopMerchantTerminal()
                currentSession = nil
            }) {
                Text("Отменить сессию")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BankTheme.textMuted)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(BankTheme.bgCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Screen 3: Success Receipt
    private var successReceiptView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.18))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(BankTheme.mint)
            }
            
            VStack(spacing: 8) {
                Text("Оплата получена!")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                
                Text("+\(Int(enteredAmount)) ₽")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(BankTheme.mint)
                
                Text("От: \(paidBuyerName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Средства моментально зачислены на ваш счёт")
                    .font(.system(size: 13))
                    .foregroundColor(BankTheme.textMuted)
            }
            
            Spacer()
            
            Button("Готово") {
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
    
    // MARK: - Keypad Logic
    private func handleKey(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if key == "C" {
            amountString = "0"
        } else if key == "⌫" {
            if amountString.count > 1 {
                amountString.removeLast()
            } else {
                amountString = "0"
            }
        } else {
            if amountString == "0" {
                amountString = key
            } else if amountString.count < 7 {
                amountString.append(key)
            }
        }
    }
    
    private func quickAddButton(_ title: String, _ delta: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let cur = Int(amountString) ?? 0
            amountString = "\(cur + delta)"
        }) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(BankTheme.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(BankTheme.mint.opacity(0.12))
                .cornerRadius(10)
        }
    }
    
    private func startTerminalSession() {
        guard enteredAmount > 0 else { return }
        isCreatingSession = true
        errorMessage = ""
        
        Task {
            do {
                let session = try await APIService.shared.createTerminalSession(
                    merchantId: merchant.id,
                    amount: enteredAmount,
                    description: description.isEmpty ? "Оплата в терминале RoPay" : description
                )
                await MainActor.run {
                    self.currentSession = session
                    self.isCreatingSession = false
                    self.tapManager.startMerchantTerminal(session: session)
                }
            } catch {
                await MainActor.run {
                    self.isCreatingSession = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Isolated Centered Ripple Circle (Fix for iOS 16/17 layout origin animation)
struct PulseRippleCircle: View {
    let size: CGFloat
    let delay: Double
    let gradientColors: [Color]
    @State private var isPulsing: Bool = false
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.15 : 0.92, anchor: .center)
            .opacity(isPulsing ? 0.25 : 0.75)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    isPulsing = true
                }
            }
    }
}
