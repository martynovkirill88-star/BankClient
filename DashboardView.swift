import SwiftUI

enum DashboardTab: Int, CaseIterable {
    case home = 0
    case history = 1
    case settings = 2
    
    var title: String {
        switch self {
        case .home: return "Главная"
        case .history: return "История операций"
        case .settings: return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

struct DashboardView: View {
    @Binding var currentUser: User?
    var onLock: () -> Void
    
    @StateObject private var btManager = BluetoothManager.shared
    @State private var selectedTab: DashboardTab = .home
    @State private var transactions: [BankTransaction] = []
    @State private var isLoadingTransactions: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var showAtmSheet: Bool = false
    @State private var isBalanceHidden: Bool = false
    
    var hasFaceBiometrics: Bool {
        guard let user = currentUser else { return false }
        return (user.has_face == true) || (user.photo_filename != nil && !user.photo_filename!.isEmpty)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            BankTheme.bgDark.ignoresSafeArea()
            
            // Tab content
            Group {
                switch selectedTab {
                case .home:
                    homeView
                case .history:
                    historyView
                case .settings:
                    SettingsView(currentUser: $currentUser, onLogout: onLock, isEmbedded: true)
                }
            }
            
            // Bottom Glass Navigation Bar
            bottomTabBar
        }
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
    
    // MARK: - Ambient Light Background
    private var ambientBackground: some View {
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
    }
    
    // MARK: - Home Tab View
    private var homeView: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                ambientBackground
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // ── Top Bar (Clean: Avatar & Name only) ─────────────
                        HStack(spacing: 14) {
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
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = .settings
                                }
                            }) {
                                FaceIDBannerContent(hasFaceBiometrics: hasFaceBiometrics)
                            }
                            .buttonStyle(.glass)
                            .padding(.horizontal, 20)
                        } else {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = .settings
                                }
                            }) {
                                FaceIDBannerContent(hasFaceBiometrics: hasFaceBiometrics)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 20)
                        }
                        
                        // ── Recent Transactions Preview ───────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("История операций")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedTab = .history
                                    }
                                }) {
                                    Text("Все")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(BankTheme.mint)
                                }
                            }
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
                                .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(transactions.prefix(3)) { tx in
                                        transactionRow(tx)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 95)
                }
                .refreshable {
                    refreshData()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - History Tab View
    private var historyView: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                ambientBackground
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("История операций")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white)
                            Text("Все операции и переводы RoPay")
                                .font(.system(size: 13))
                                .foregroundColor(BankTheme.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if isLoadingTransactions {
                            ProgressView()
                                .tint(BankTheme.mint)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else if transactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(BankTheme.textMuted)
                                Text("История операций пока пуста")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Здесь будут отображаться ваши переводы клиентам RoPay")
                                    .font(.system(size: 13))
                                    .foregroundColor(BankTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(transactions) { tx in
                                    transactionRow(tx)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 95)
                }
                .refreshable {
                    loadTransactions()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Transaction Row
    private func transactionRow(_ tx: BankTransaction) -> some View {
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
    
    // MARK: - Bottom Glass Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 8) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                
                if #available(iOS 26.0, *) {
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(isSelected ? BankTheme.mint : BankTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(isSelected ? BankTheme.mint : BankTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? BankTheme.mint.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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
