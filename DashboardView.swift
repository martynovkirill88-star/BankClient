import SwiftUI

struct DashboardView: View {
    @Binding var currentUser: User?
    var onLock: () -> Void
    
    @StateObject private var btManager = BluetoothManager.shared
    @State private var transactions: [BankTransaction] = []
    @State private var isLoadingTransactions: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var showAtmSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var isBalanceHidden: Bool = false
    
    var hasFaceBiometrics: Bool {
        guard let user = currentUser else { return false }
        return (user.has_face == true) || (user.photo_filename != nil && !user.photo_filename!.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                // Ambient Fluid Light Underlay
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [BankTheme.mint.opacity(0.12), Color.clear],
                            center: .center, startRadius: 10, endRadius: 200
                        ))
                        .frame(width: 350, height: 350)
                        .blur(radius: 55)
                        .offset(x: 100, y: -200)
                    
                    Circle()
                        .fill(RadialGradient(
                            colors: [BankTheme.purple.opacity(0.18), Color.clear],
                            center: .center, startRadius: 20, endRadius: 230
                        ))
                        .frame(width: 400, height: 400)
                        .blur(radius: 65)
                        .offset(x: -80, y: 180)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // ── Top Bar ──────────────────────────────────────
                        HStack(spacing: 14) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(BankTheme.mint.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Text(userInitial)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(BankTheme.mint)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentUser?.fullName ?? "Клиент")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.white)
                                Text("Активный счёт RoPay")
                                    .font(.system(size: 12))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            
                            Spacer()
                            
                            // Refresh, Settings, Lock buttons
                            HStack(spacing: 10) {
                                GlassIconButton(icon: "arrow.clockwise", action: refreshData)
                                GlassIconButton(icon: "gearshape.fill", tint: BankTheme.mint) {
                                    showSettingsSheet = true
                                }
                                GlassIconButton(icon: "lock.fill", action: onLock)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // ── Phone Number Card ─────────────────────────────
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("МОЙ НОМЕР ДЛЯ ПЕРЕВОДОВ")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                Text(currentUser?.phone ?? "+7 (999) 000-00-00")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button(action: copyPhone) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(BankTheme.mint)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .padding(.horizontal, 20)
                        
                        // ── Balance Card ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Текущий баланс")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(BankTheme.textMuted)
                                Button(action: { isBalanceHidden.toggle() }) {
                                    Image(systemName: isBalanceHidden ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(BankTheme.textMuted)
                                }
                                Spacer()
                                Text("RUB ₽")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BankTheme.mint)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(BankTheme.mint.opacity(0.12))
                                    .cornerRadius(8)
                            }
                            
                            Text(isBalanceHidden ? "•••••• ₽" : (currentUser?.formattedBalance ?? "0 ₽"))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.white)
                            
                            // ── Action Buttons: Перевести / Банкомат ──────
                            HStack(spacing: 12) {
                                if #available(iOS 26.0, *) {
                                    Button(action: { showTransferSheet = true }) {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                            Text("Перевести")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(.glass)
                                    
                                    Button(action: { showAtmSheet = true }) {
                                        HStack {
                                            Image(systemName: "bolt.fill")
                                            Text("В банкомат")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .foregroundColor(BankTheme.purple)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(.glass)
                                } else {
                                    Button(action: { showTransferSheet = true }) {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                            Text("Перевести")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                        .foregroundColor(.white)
                                    }
                                    Button(action: { showAtmSheet = true }) {
                                        HStack {
                                            Image(systemName: "bolt.fill")
                                            Text("В банкомат")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                        .foregroundColor(BankTheme.purple)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        // ── Bluetooth Banner ──────────────────────────────
                        if #available(iOS 26.0, *) {
                            Button(action: { showAtmSheet = true }) {
                                BtBannerContent(btManager: btManager)
                            }
                            .buttonStyle(.glass)
                            .padding(.horizontal, 20)
                        } else {
                            Button(action: { showAtmSheet = true }) {
                                BtBannerContent(btManager: btManager)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 20)
                        }
                        
                        // ── Face ID Banner ────────────────────────────────
                        if #available(iOS 26.0, *) {
                            Button(action: { showSettingsSheet = true }) {
                                FaceIDBannerContent(hasFaceBiometrics: hasFaceBiometrics)
                            }
                            .buttonStyle(.glass)
                            .padding(.horizontal, 20)
                        } else {
                            Button(action: { showSettingsSheet = true }) {
                                FaceIDBannerContent(hasFaceBiometrics: hasFaceBiometrics)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 20)
                        }
                        
                        // ── Transactions ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            Text("История операций")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            if isLoadingTransactions {
                                ProgressView()
                                    .tint(BankTheme.mint)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else if transactions.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(BankTheme.textMuted)
                                    Text("История операций пока пуста")
                                        .font(.system(size: 14))
                                        .foregroundColor(BankTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(transactions) { tx in
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(tx.isPositive ? BankTheme.mint.opacity(0.12) : BankTheme.bgCardSubtle)
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: tx.iconName)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(tx.isPositive ? BankTheme.mint : BankTheme.textMuted)
                                            }
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(tx.title)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                if let date = tx.created_at {
                                                    Text(date)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(BankTheme.textMuted)
                                                }
                                            }
                                            Spacer()
                                            Text(tx.formattedAmount)
                                                .font(.system(size: 15, weight: .black))
                                                .foregroundColor(tx.isPositive ? BankTheme.mint : BankTheme.textMuted)
                                        }
                                        .padding(14)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showTransferSheet) {
                if let user = currentUser {
                    TransferView(currentUser: user, onTransferCompleted: { newBal in
                        currentUser?.balance = newBal
                        loadTransactions()
                    })
                }
            }
            .sheet(isPresented: $showAtmSheet) {
                if let user = currentUser {
                    BluetoothAtmView(currentUser: user)
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(currentUser: $currentUser, onLogout: onLock)
            }
            .onAppear {
                NotificationManager.shared.requestPermission()
                if let user = currentUser {
                    APIService.shared.startTransactionNotifications(userId: user.id)
                }
                btManager.startScanning()
                loadTransactions()
            }
            .onDisappear {
                APIService.shared.stopTransactionNotifications()
            }
        }
    }
    
    private var userInitial: String {
        guard let name = currentUser?.name, let first = name.first else { return "К" }
        return String(first).uppercased()
    }
    
    private func copyPhone() {
        guard let phone = currentUser?.phone else { return }
        UIPasteboard.general.string = phone
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func refreshData() {
        guard let user = currentUser else { return }
        Task {
            do {
                let updated = try await APIService.shared.fetchProfile(userId: user.id)
                await MainActor.run { currentUser = updated; loadTransactions() }
            } catch { print("Refresh error: \(error)") }
        }
    }
    
    private func loadTransactions() {
        guard let user = currentUser else { return }
        isLoadingTransactions = true
        Task {
            do {
                let list = try await APIService.shared.fetchTransactions(userId: user.id)
                await MainActor.run { isLoadingTransactions = false; transactions = list }
            } catch {
                await MainActor.run { isLoadingTransactions = false }
            }
        }
    }
}

// MARK: - Glass Icon Button (Refresh / Settings / Lock)
struct GlassIconButton: View {
    let icon: String
    var tint: Color = .white
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
}

// MARK: - Bluetooth Banner Content
struct BtBannerContent: View {
    @ObservedObject var btManager: BluetoothManager
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(btManager.isAtmNearby ? BankTheme.mint.opacity(0.22) : BankTheme.purple.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: btManager.isAtmNearby ? "bolt.fill" : "wave.3.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(btManager.isAtmNearby ? BankTheme.mint : BankTheme.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(btManager.isAtmNearby ? "⚡ Банкомат обнаружен рядом!" : "Бесконтактный вход по Bluetooth")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(btManager.isAtmNearby ? "Нажмите для мгновенного входа" : "Поднесите телефон к банкомату")
                    .font(.system(size: 12))
                    .foregroundColor(BankTheme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(BankTheme.textMuted)
        }
        .padding(14)
    }
}

// MARK: - Face ID Banner Content
struct FaceIDBannerContent: View {
    let hasFaceBiometrics: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(hasFaceBiometrics ? BankTheme.mint.opacity(0.22) : BankTheme.purple.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: "faceid")
                    .font(.system(size: 20))
                    .foregroundColor(hasFaceBiometrics ? BankTheme.mint : BankTheme.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(hasFaceBiometrics ? "Face ID в банкомате подключен" : "Вход по Face ID в банкомат")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(hasFaceBiometrics ? "Нажмите для обновления фото" : "Нажмите, чтобы сделать снимок лица")
                    .font(.system(size: 12))
                    .foregroundColor(BankTheme.textMuted)
            }
            Spacer()
            Text(hasFaceBiometrics ? "Активен" : "Подключить")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(hasFaceBiometrics ? BankTheme.mint : .white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(hasFaceBiometrics ? BankTheme.mint.opacity(0.18) : BankTheme.purple.opacity(0.5))
                .cornerRadius(10)
        }
        .padding(14)
    }
}
