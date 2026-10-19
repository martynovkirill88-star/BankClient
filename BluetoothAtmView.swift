import SwiftUI
import Combine
import LocalAuthentication

struct BluetoothAtmView: View {
    let currentUser: User
    @Environment(\.dismiss) private var dismiss
    @StateObject private var btManager = BluetoothManager.shared
    
    @State private var manualCode: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var radarPulse: Bool = false
    @State private var showManualInput: Bool = false
    
    private let pollTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var activeCode: String {
        btManager.detectedAtmCode ?? manualCode
    }
    
    var canConfirm: Bool {
        if !manualCode.isEmpty && manualCode.count == 6 {
            return true
        }
        // Strict Proximity: Must be touching the screen (RSSI >= -50 dBm) AND have code
        return btManager.isVeryClose && !activeCode.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header description
                        Text("Поднесите iPhone вплотную к экрану банкомата RoPay для бесконтактного входа")
                            .font(.system(size: 14))
                            .foregroundColor(BankTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Animated Bluetooth Radar
                        ZStack {
                            ForEach(0..<3) { i in
                                Circle()
                                    .stroke(
                                        btManager.isAtmNearby ? BankTheme.mint.opacity(0.4) : BankTheme.purple.opacity(0.3),
                                        lineWidth: 2
                                    )
                                    .frame(width: CGFloat(120 + i * 50), height: CGFloat(120 + i * 50))
                                    .scaleEffect(radarPulse ? 1.15 : 0.9)
                                    .opacity(radarPulse ? 0.3 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 1.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.25),
                                        value: radarPulse
                                    )
                            }
                            
                            ZStack {
                                Circle()
                                    .fill(btManager.isAtmNearby ? BankTheme.mint.opacity(0.2) : BankTheme.purple.opacity(0.2))
                                    .frame(width: 90, height: 90)
                                    .shadow(color: btManager.isAtmNearby ? BankTheme.mint.opacity(0.5) : BankTheme.purple.opacity(0.3), radius: 20)
                                
                                Image(systemName: btManager.isAtmNearby ? "bolt.fill" : "wave.3.forward.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(btManager.isAtmNearby ? BankTheme.mint : BankTheme.purple)
                            }
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                        
                        // Live Status Pill
                        HStack(spacing: 8) {
                            Circle()
                                .fill(canConfirm ? BankTheme.mint : Color.yellow)
                                .frame(width: 10, height: 10)
                            
                            Text(btManager.proximityText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(BankTheme.bgCard)
                        .cornerRadius(20)
                        
                        // Detected Code Card (Automatically discovered via BLE or Local Server)
                        if !activeCode.isEmpty {
                            VStack(spacing: 6) {
                                Text("КОД БАНКОМАТА ОБНАРУЖЕН")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.mint)
                                
                                Text(formatCode(activeCode))
                                    .font(.system(size: 34, weight: .black, design: .monospaced))
                                    .foregroundColor(BankTheme.mint)
                                    .tracking(6)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(BankTheme.mint.opacity(0.12))
                            .cornerRadius(18)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(BankTheme.mint, lineWidth: 2))
                            .padding(.horizontal, 20)
                        }
                        
                        // Action Button: Instant Contactless Confirmation
                        Button(action: confirmAtmLogin) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 10) {
                                    if canConfirm {
                                        Image(systemName: "bolt.fill")
                                        Text("Войти в банкомат (Нажмите)")
                                    } else if !activeCode.isEmpty && !btManager.isVeryClose {
                                        Image(systemName: "hand.tap.fill")
                                        Text("Поднесите вплотную к экрану")
                                    } else {
                                        Image(systemName: "wave.3.forward.circle")
                                        Text("Поиск банкомата рядом...")
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(canConfirm ? .white : BankTheme.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            canConfirm ? AnyShapeStyle(BankTheme.purpleGradient) : AnyShapeStyle(Color.gray.opacity(0.2))
                        )
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .disabled(!canConfirm || isLoading)
                        
                        // Optional manual input toggle (if user ever wants to type manually)
                        Button(action: { withAnimation { showManualInput.toggle() } }) {
                            Text(showManualInput ? "Скрыть ручной ввод" : "Ввести 6 цифр вручную")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BankTheme.textMuted)
                        }
                        .padding(.top, 4)
                        
                        if showManualInput {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("123 456", text: $manualCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(BankTheme.bgCard)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Банкомат RoPay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
            .onReceive(pollTimer) { _ in
                btManager.checkLiveness()
                btManager.restartScanIfNeeded()
                checkActiveAtm()
            }
            .onAppear {
                radarPulse = true
                btManager.startScanning()
                btManager.startAdvertising(userId: currentUser.id)
                checkActiveAtm()
            }
            .onDisappear {
                btManager.stopScanning()
                btManager.stopAdvertising()
                btManager.resetDetection()
            }
            .alert("Вход в банкомат", isPresented: $showAlert) {
                Button("ОК") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func checkActiveAtm() {
        Task {
            do {
                let serverCode = try await APIService.shared.fetchActiveAtmCode()
                await MainActor.run {
                    btManager.setServerActiveCode(serverCode)
                }
            } catch {}
        }
    }
    
    private func formatCode(_ code: String) -> String {
        if code.count == 6 {
            let p1 = code.prefix(3)
            let p2 = code.suffix(3)
            return "\(p1) \(p2)"
        }
        return code
    }
    
    private func confirmAtmLogin() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Подтвердите вход в банкомат") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        executeAtmLoginApi()
                    }
                }
            }
        } else {
            executeAtmLoginApi()
        }
    }
    
    private func executeAtmLoginApi() {
        isLoading = true
        
        Task {
            do {
                let codeToSend = activeCode.isEmpty ? nil : activeCode
                let msg = try await APIService.shared.loginToAtm(
                    userId: currentUser.id,
                    code: codeToSend
                )
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    alertMessage = "🎉 \(msg)\nВзгляните на экран банкомата — он открыт!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}
