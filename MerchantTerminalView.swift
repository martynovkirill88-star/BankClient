import SwiftUI
import AudioToolbox
import CoreImage
import CoreImage.CIFilterBuiltins

enum PaymentTarget: String, CaseIterable, Identifiable {
    case thisDevice = "this"
    case posTerminal = "pos"
    
    var id: String { rawValue }
    var title: String {
        switch self {
        case .thisDevice: return "На этом iPhone"
        case .posTerminal: return "Терминал RoPay"
        }
    }
    
    var icon: String {
        switch self {
        case .thisDevice: return "iphone"
        case .posTerminal: return "display"
        }
    }
}

// MARK: - POS Terminal View for Business Profiles
struct MerchantTerminalView: View {
    @Environment(\.dismiss) private var dismiss
    let merchant: User
    var onPaymentReceived: ((Double) -> Void)?
    
    @StateObject private var tapManager = TapPaymentManager.shared
    
    @State private var paymentTarget: PaymentTarget = .thisDevice
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
                    if paymentTarget == .thisDevice {
                        waitingForCustomerTouchView(session: session)
                            .transition(.identity)
                    } else {
                        waitingOnPosTerminalView(session: session)
                            .transition(.identity)
                    }
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
                        cancelActiveSession()
                        dismiss()
                    }
                    .foregroundColor(BankTheme.mint)
                }
            }
            .onDisappear {
                cancelActiveSession()
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
            
            // Payment Target Selector Pill
            HStack(spacing: 8) {
                targetButton(.thisDevice)
                targetButton(.posTerminal)
            }
            .padding(.horizontal, 20)
            
            // Submit Button
            Button(action: startTerminalSession) {
                HStack(spacing: 10) {
                    if isCreatingSession {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: paymentTarget == .thisDevice ? "iphone.radiowaves.left.and.right" : "display.and.arrow.down")
                            .font(.system(size: 18, weight: .bold))
                        Text(paymentTarget == .thisDevice ? "Принять оплату касанием" : "Отправить на терминал RoPay")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enteredAmount > 0 ? (paymentTarget == .thisDevice ? BankTheme.mint : BankTheme.gold) : Color.gray.opacity(0.4))
                .cornerRadius(18)
                .shadow(color: enteredAmount > 0 ? (paymentTarget == .thisDevice ? BankTheme.mint.opacity(0.3) : BankTheme.gold.opacity(0.3)) : .clear, radius: 10, y: 4)
            }
            .disabled(enteredAmount <= 0 || isCreatingSession)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Screen 2: Waiting for Payment (Contactless iPhone Tap + Android QR-Code)
    private func waitingForCustomerTouchView(session: TerminalSession) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header Amount & Business Name
                VStack(spacing: 4) {
                    Text(displayBusinessName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BankTheme.gold)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(session.amount))")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("₽")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(BankTheme.mint)
                    }
                }
                .padding(.top, 8)
                
                // Contactless Aura Radar with App Icon
                ZStack(alignment: .center) {
                    PulseRippleCircle(size: 150, delay: 0.5, gradientColors: [BankTheme.mint.opacity(0.7), BankTheme.purple.opacity(0.35)])
                    PulseRippleCircle(size: 120, delay: 0.25, gradientColors: [BankTheme.mint.opacity(0.7), BankTheme.purple.opacity(0.35)])
                    PulseRippleCircle(size: 90, delay: 0.0, gradientColors: [BankTheme.mint.opacity(0.7), BankTheme.purple.opacity(0.35)])
                    
                    ZStack {
                        Circle()
                            .fill(BankTheme.bgCard)
                            .frame(width: 76, height: 76)
                            .overlay(Circle().stroke(BankTheme.mint, lineWidth: 2))
                            .shadow(color: BankTheme.mint.opacity(0.4), radius: 15)
                        
                        VStack(spacing: 3) {
                            Image(systemName: "wave.3.forward.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                            
                            Text("RoPay Tap")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 155, height: 155, alignment: .center)
                
                // QR-Code for Android / Camera Scan
                VStack(spacing: 8) {
                    if let qrImg = QRCodeGenerator.generate(from: "ropay://terminal/pay?session_id=\(session.id)&amount=\(session.amount)", size: 160) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(width: 160, height: 160)
                                .shadow(color: Color.black.opacity(0.4), radius: 10)
                            
                            Image(uiImage: qrImg)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 144, height: 144)
                            
                            // Center App Badge
                            Circle()
                                .fill(Color(red: 0.05, green: 0.06, blue: 0.09))
                                .frame(width: 32, height: 32)
                            Image(systemName: "wave.3.forward.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(BankTheme.mint)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(BankTheme.gold)
                        Text("QR-код для оплаты (Android)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(BankTheme.gold)
                    }
                }
                .padding(.top, 4)
                
                // Dual Instructions
                VStack(spacing: 4) {
                    Text("Приложите iPhone или отсканируйте QR")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Для iPhone: приложите телефон вплотную спинкой\nДля Android: отсканируйте QR-код в приложении")
                        .font(.system(size: 12))
                        .foregroundColor(BankTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 6)
                
                // Cancel button
                Button(action: cancelActiveSession) {
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
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Screen 2b: Waiting on RoPay POS Terminal (iPhone 5)
    private func waitingOnPosTerminalView(session: TerminalSession) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Header Amount & Business Name
            VStack(spacing: 4) {
                Text(displayBusinessName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BankTheme.gold)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(session.amount))")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("₽")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(BankTheme.mint)
                }
            }
            .padding(.top, 10)
            
            // Animated Pulse Radar with Terminal Display Icon
            ZStack(alignment: .center) {
                PulseRippleCircle(size: 160, delay: 0.5, gradientColors: [BankTheme.gold.opacity(0.7), BankTheme.mint.opacity(0.35)])
                PulseRippleCircle(size: 125, delay: 0.25, gradientColors: [BankTheme.gold.opacity(0.7), BankTheme.mint.opacity(0.35)])
                PulseRippleCircle(size: 92, delay: 0.0, gradientColors: [BankTheme.gold.opacity(0.7), BankTheme.mint.opacity(0.35)])
                
                ZStack {
                    Circle()
                        .fill(BankTheme.bgCard)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(BankTheme.gold, lineWidth: 2))
                        .shadow(color: BankTheme.gold.opacity(0.4), radius: 15)
                    
                    VStack(spacing: 3) {
                        Image(systemName: "display")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(BankTheme.gold)
                        
                        Text("ТЕРМИНАЛ")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(BankTheme.gold)
                    }
                }
            }
            .frame(width: 165, height: 165, alignment: .center)
            
            // Status Info Card
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Счёт отправлен на терминал")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Сумма \(Int(session.amount)) ₽ выведена на терминал покупателя (iPhone 5).\nОжидаем оплату касанием телефона или по QR-коду.")
                    .font(.system(size: 13))
                    .foregroundColor(BankTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(18)
            .background(BankTheme.bgCard)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(BankTheme.border, lineWidth: 1))
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Cancel Button
            Button(action: cancelActiveSession) {
                Text("Отменить счёт на терминале")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BankTheme.coral)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(BankTheme.coral.opacity(0.12))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.coral.opacity(0.3), lineWidth: 1))
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
    
    private func targetButton(_ target: PaymentTarget) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                paymentTarget = target
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: target.icon)
                    .font(.system(size: 13, weight: .bold))
                Text(target.title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(paymentTarget == target ? .black : BankTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(paymentTarget == target ? (target == .thisDevice ? BankTheme.mint : BankTheme.gold) : BankTheme.bgCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(paymentTarget == target ? (target == .thisDevice ? BankTheme.mint : BankTheme.gold) : BankTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleTouchButtonStyle())
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
                    
                    // Only start local Bluetooth broadcast if merchant accepts on this phone
                    if self.paymentTarget == .thisDevice {
                        self.tapManager.startMerchantTerminal(session: session)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCreatingSession = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func cancelActiveSession() {
        tapManager.stopMerchantTerminal()
        if let session = currentSession {
            let sid = session.id
            Task {
                try? await APIService.shared.cancelTerminalSession(sessionId: sid)
            }
        }
        currentSession = nil
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

// MARK: - Native QR Code Generator
struct QRCodeGenerator {
    static let context = CIContext()
    
    static func generate(from string: String, size: CGFloat = 200) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter?.outputImage else { return nil }
        
        let extent = outputImage.extent
        let scale = size / extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
