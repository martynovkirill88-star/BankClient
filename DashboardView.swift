import SwiftUI

struct DashboardView: View {
    @Binding var currentUser: User?
    var onLock: () -> Void
    
    @StateObject private var btManager = BluetoothManager.shared
    @State private var selectedTab: Int = 0
    @State private var transactions: [BankTransaction] = []
    @State private var isLoadingTransactions: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var showAtmSheet: Bool = false
    @State private var isBalanceHidden: Bool = false
    @State private var showBleUpcomingAlert: Bool = false
    
    // Statuses / Stories State
    @State private var statuses: [BankStatus] = []
    @State private var selectedStatusForViewer: BankStatus? = nil
    @AppStorage("viewed_statuses_ids") private var viewedStatusesCSV: String = ""
    
    var viewedIdsSet: Set<Int> {
        let items = viewedStatusesCSV.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return Set(items)
    }
    
    var sortedStatuses: [BankStatus] {
        let unviewed = statuses.filter { !viewedIdsSet.contains($0.id) }
        let viewed = statuses.filter { viewedIdsSet.contains($0.id) }
        return unviewed + viewed
    }
    
    func markStatusAsViewed(_ id: Int) {
        var set = viewedIdsSet
        if !set.contains(id) {
            set.insert(id)
            viewedStatusesCSV = set.map(String.init).joined(separator: ",")
            APIService.shared.recordStatusView(statusId: id)
        }
    }
    
    func loadStatuses() {
        Task {
            do {
                let fetched = try await APIService.shared.fetchStatuses(platform: "ios")
                await MainActor.run {
                    self.statuses = fetched
                }
            } catch {
                print("Error loading statuses: \(error)")
            }
        }
    }
    
    var hasFaceBiometrics: Bool {
        guard let user = currentUser else { return false }
        return (user.has_face == true) || (user.photo_filename != nil && !user.photo_filename!.isEmpty)
    }
    
    var body: some View {
        if #available(iOS 18.0, *) {
            nativeTabView
        } else {
            legacyTabView
        }
    }
    
    // MARK: - iOS 18+ Native TabView with Liquid Glass
    @available(iOS 18.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Главная", systemImage: "house.fill", value: 0) {
                homeView
            }
            Tab("История", systemImage: "clock.fill", value: 1) {
                historyView
            }
            Tab("Настройки", systemImage: "gearshape.fill", value: 2) {
                SettingsView(currentUser: $currentUser, onLogout: onLock, isEmbedded: true)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
        .fullScreenCover(item: $selectedStatusForViewer) { initialStatus in
            StoryViewer(
                initialStatus: initialStatus,
                statuses: sortedStatuses,
                onStatusViewed: { viewedId in markStatusAsViewed(viewedId) },
                onDismiss: { selectedStatusForViewer = nil }
            )
        }
        .alert("Скоро будет доступно", isPresented: $showBleUpcomingAlert) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text("Бесконтактный вход по Bluetooth скоро появится в приложении банка RoPay.")
        }
        .onAppear(perform: onViewAppear)
        .onDisappear { APIService.shared.stopTransactionNotifications() }
    }
    
    // MARK: - iOS 16/17 Fallback TabView
    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            BankTheme.bgDark.ignoresSafeArea()
            
            Group {
                switch selectedTab {
                case 0: homeView
                case 1: historyView
                case 2: SettingsView(currentUser: $currentUser, onLogout: onLock, isEmbedded: true)
                default: homeView
                }
            }
            
            // Fallback: кастомный таб-бар с тёмным фоном
            LegacyTabBar(selectedTab: $selectedTab)
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
        .fullScreenCover(item: $selectedStatusForViewer) { initialStatus in
            StoryViewer(
                initialStatus: initialStatus,
                statuses: sortedStatuses,
                onStatusViewed: { viewedId in markStatusAsViewed(viewedId) },
                onDismiss: { selectedStatusForViewer = nil }
            )
        }
        .alert("Скоро будет доступно", isPresented: $showBleUpcomingAlert) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text("Бесконтактный вход по Bluetooth скоро появится в приложении банка RoPay.")
        }
        .onAppear(perform: onViewAppear)
        .onDisappear { APIService.shared.stopTransactionNotifications() }
    }
    
    private func onViewAppear() {
        NotificationManager.shared.requestPermission()
        if let user = currentUser {
            APIService.shared.startTransactionNotifications(userId: user.id)
        }
        btManager.startScanning()
        loadTransactions()
        loadStatuses()
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
                        
                        // ── Top Bar (GlassTopBar by Ricky Aguilar Pattern) ──
                        GlassTopBar(
                            userInitial: userInitial,
                            userName: currentUser?.fullName ?? "Клиент"
                        )
                        
                        // ── Stories / Statuses Bar ────────────────────────
                        if !statuses.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(sortedStatuses) { status in
                                        StatusSquareItem(
                                            status: status,
                                            isViewed: viewedIdsSet.contains(status.id),
                                            onTap: {
                                                selectedStatusForViewer = status
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 2)
                            }
                        }
                        
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
                                    
                                    Button(action: { showBleUpcomingAlert = true }) {
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
                                    Button(action: { showBleUpcomingAlert = true }) {
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
                            Button(action: { showBleUpcomingAlert = true }) {
                                BtBannerContent(btManager: btManager)
                            }
                            .buttonStyle(.glass)
                            .padding(.horizontal, 20)
                        } else {
                            Button(action: { showBleUpcomingAlert = true }) {
                                BtBannerContent(btManager: btManager)
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
                                        selectedTab = 1
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
                    .padding(.bottom, 110) // legacyTabView padding compensation
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
                    .padding(.bottom, 110) // legacyTabView padding compensation
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
                Image(systemName: tx.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(tx.isPositive ? BankTheme.mint : BankTheme.textMuted)
            }
            .frame(width: 44, height: 44)
            
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

// MARK: - Glass Top Bar (Ricky Aguilar Pattern)
struct GlassTopBar: View {
    let userInitial: String
    let userName: String
    
    var body: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            HStack {
                // Основной контент топ-бара (аватар, имя, статус)
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .glassEffect(cornerRadius: 24) // Нативный системный модификатор стекла
            .tabBarMinimizeBehavior(.onScrollDown) // Динамическое уменьшение/скрытие при скролле
            .cornerRadius(24)
            .padding(.horizontal, 16)
            .padding(.top, 10)
        } else {
            // Фоллбэк для старых версий
            fallbackBar
        }
        #endif
    }
    
    private var content: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(userInitial)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(BankTheme.mint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
                Text("Активный счёт RoPay")
                    .font(.system(size: 12))
                    .foregroundColor(BankTheme.textMuted)
            }
            
            Spacer()
        }
    }
    
    private var fallbackBar: some View {
        HStack {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

// MARK: - Legacy Tab Bar (iOS 16/17 fallback)
struct LegacyTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            TabBarButton(icon: "house.fill", title: "Главная", tag: 0, selection: $selectedTab)
            TabBarButton(icon: "clock.fill", title: "История", tag: 1, selection: $selectedTab)
            TabBarButton(icon: "gearshape.fill", title: "Настройки", tag: 2, selection: $selectedTab)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(32)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let tag: Int
    @Binding var selection: Int
    
    var isSelected: Bool {
        selection == tag
    }
    
    var body: some View {
        Button(action: {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selection = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                Text(title)
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
