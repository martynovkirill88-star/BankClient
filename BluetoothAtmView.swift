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
    private let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    var activeCode: String {
        btManager.detectedAtmCode ?? manualCode
    }
    
    var canConfirm: Bool {
        if !manualCode.isEmpty && manualCode.count == 6 {
            return true
        }
        return !activeCode.isEmpty && btManager.isVeryClose
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header description
                        Text("Поднесите iPhone к банкомату RoPay для автоматического распознавания через Bluetooth")
                            .font(.system(size: 14))
                            .foregroundColor(BankTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Animated Bluetooth Radar
                        ZStack {
                            // Concentric pulsing radar rings
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
                            
                            // Center Glowing Icon
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
                        .frame(height: 220)
                        .padding(.vertical, 10)
                        
                        // Live Status Pill
                        HStack(spacing: 8) {
                            Circle()
                                .fill(btManager.isAtmNearby ? (btManager.isVeryClose ? BankTheme.mint : Color.yellow) : (btManager.isScanning ? Color.yellow : Color.gray))
                                .frame(width: 10, height: 10)
                            
                            Text(btManager.proximityText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(BankTheme.bgCard)
                        .cornerRadius(20)
                        
                        // Detected Code Card (if found by Bluetooth)
                        if let detected = btManager.detectedAtmCode {
                            VStack(spacing: 6) {
                                Text("КОД БАНКОМАТА ПО BLUETOOTH")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                
                                Text(formatCode(detected))
                                    .font(.system(size: 32, weight: .black, design: .monospaced))
                                    .foregroundColor(btManager.isVeryClose ? BankTheme.mint : Color.yellow)
                                    .tracking(6)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(BankTheme.mint.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(btManager.isVeryClose ? BankTheme.mint : Color.yellow.opacity(0.5), lineWidth: 1.5))
                            .padding(.horizontal, 20)
                        } else {
                            // Manual Code Entry Fallback
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ИЛИ ВВЕДИТЕ 6 ЦИФР С ЭКРАНА БАНКОМАТА")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                
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
                        }
                        
                        // Action Button
                        Button(action: confirmAtmLogin) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 10) {
                                    if canConfirm {
                                        Image(systemName: "bolt.fill")
                                        Text("Подтвердить вход в банкомате")
                                    } else if btManager.isAtmNearby {
                                        Image(systemName: "hand.tap.fill")
                                        Text("Поднесите телефон вплотную")
                                    } else {
                                        Image(systemName: "wave.3.forward")
                                        Text("Поиск банкомата RoPay...")
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
                        
                        // Rescan Button
                        Button(action: {
                            btManager.resetDetection()
                            btManager.startScanning()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Обновить поиск Bluetooth")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BankTheme.textMuted)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Банкомат RoPay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(BankTheme.mint)
                }
            }
            .onReceive(pollTimer) { _ in
                btManager.restartScanIfNeeded()
                Task {
                    do {
                        if let serverCode = try await APIService.shared.fetchActiveAtmCode(), serverCode.count == 6 {
                            await MainActor.run {
                                if btManager.isAtmNearby && btManager.detectedAtmCode == nil {
                                    btManager.detectedAtmCode = serverCode
                                }
                            }
                        }
                    } catch {}
                }
            }
            .onAppear {
                radarPulse = true
                btManager.startScanning()
                Task {
                    do {
                        if let serverCode = try await APIService.shared.fetchActiveAtmCode(), serverCode.count == 6 {
                            await MainActor.run {
                                if btManager.isAtmNearby && btManager.detectedAtmCode == nil {
                                    btManager.detectedAtmCode = serverCode
                                }
                            }
                        }
                    } catch {}
                }
            }
            .onDisappear {
                btManager.stopScanning()
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
    
    private func formatCode(_ code: String) -> String {
        if code.count == 6 {
            let p1 = code.prefix(3)
            let p2 = code.suffix(3)
            return "\(p1) \(p2)"
        }
        return code
    }
    
    private func confirmAtmLogin() {
        guard !activeCode.isEmpty else { return }
        
        let context = LAContext()
        var error: NSError?
        
        // Optional Face ID check before approving ATM entrance
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
                let msg = try await APIService.shared.loginToAtm(
                    userId: currentUser.id,
                    code: activeCode
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
