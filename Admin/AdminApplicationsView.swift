import SwiftUI

struct AdminApplicationsView: View {
    @StateObject private var api = AdminAPIService.shared
    
    @State private var applications: [AdminApplication] = []
    @State private var isLoading: Bool = false
    @State private var selectedFilter: String = "pending"
    @State private var errorMessage: String = ""
    
    // Approval modal state
    @State private var appToApprove: AdminApplication? = nil
    @State private var initialBalanceString: String = "50000"
    @State private var isProcessing: Bool = false
    
    var filteredApplications: [AdminApplication] {
        if selectedFilter == "all" { return applications }
        return applications.filter { $0.status == selectedFilter }
    }
    
    var pendingCount: Int {
        applications.filter { $0.status == "pending" }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Pills
                    HStack(spacing: 8) {
                        filterPill(title: "В ожидании (\(pendingCount))", tag: "pending")
                        filterPill(title: "Одобренные", tag: "approved")
                        filterPill(title: "Отклоненные", tag: "rejected")
                        filterPill(title: "Все", tag: "all")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    if isLoading && applications.isEmpty {
                        Spacer()
                        ProgressView().tint(AdminTheme.mint)
                        Spacer()
                    } else if filteredApplications.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 44))
                                .foregroundColor(AdminTheme.textSecondary.opacity(0.6))
                            Text("Нет заявок в данном разделе")
                                .font(.system(size: 15))
                                .foregroundColor(AdminTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredApplications) { app in
                                    applicationCard(app)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await loadData()
                        }
                    }
                }
            }
            .navigationTitle("Заявки на открытие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadData() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AdminTheme.mint)
                    }
                }
            }
            .task {
                await loadData()
            }
            .sheet(item: $appToApprove) { app in
                approveSheet(app: app)
            }
        }
    }
    
    // MARK: - Filter Pill
    private func filterPill(title: String, tag: String) -> some View {
        let isSelected = selectedFilter == tag
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = tag
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : AdminTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AdminTheme.mint : AdminTheme.bgCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AdminTheme.border, lineWidth: isSelected ? 0 : 1))
        }
    }
    
    // MARK: - Application Card
    private func applicationCard(_ app: AdminApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.fullName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Заявка #\(app.id) • \(app.created_at ?? "")")
                        .font(.system(size: 11))
                        .foregroundColor(AdminTheme.textSecondary)
                }
                
                Spacer()
                
                statusBadge(status: app.status)
            }
            
            Divider().background(AdminTheme.border)
            
            // Details Grid
            VStack(spacing: 8) {
                detailRow(icon: "phone.fill", title: "Телефон для переводов", value: app.phone)
                detailRow(icon: "lock.fill", title: "Желаемый ПИН-код", value: app.pin_code)
                detailRow(icon: "paperplane.fill", title: "Telegram", value: app.telegram)
            }
            
            // Actions
            HStack(spacing: 10) {
                // Open Telegram Button
                if !app.telegramClean.isEmpty {
                    Button(action: {
                        let tgUrl = URL(string: "tg://resolve?domain=\(app.telegramClean)")!
                        let webUrl = URL(string: "https://t.me/\(app.telegramClean)")!
                        if UIApplication.shared.canOpenURL(tgUrl) {
                            UIApplication.shared.open(tgUrl)
                        } else {
                            UIApplication.shared.open(webUrl)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                            Text("Написать")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.cyan)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .background(Color.cyan.opacity(0.14))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                if app.status == "pending" {
                    Button(action: {
                        Task { await reject(app) }
                    }) {
                        Text("Отклонить")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AdminTheme.danger)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 14)
                            .background(AdminTheme.danger.opacity(0.12))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        appToApprove = app
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Одобрить")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 16)
                        .background(AdminTheme.mint)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(AdminTheme.bgCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AdminTheme.border, lineWidth: 1))
    }
    
    private func statusBadge(status: String) -> some View {
        let (color, text) = { () -> (Color, String) in
            switch status {
            case "approved": return (AdminTheme.mint, "Одобрено")
            case "rejected": return (AdminTheme.danger, "Отклонено")
            default: return (AdminTheme.gold, "В ожидании")
            }
        }()
        
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AdminTheme.mint)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(AdminTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Approve Sheet
    private func approveSheet(app: AdminApplication) -> some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Клиент:")
                            .font(.system(size: 12))
                            .foregroundColor(AdminTheme.textSecondary)
                        Text(app.fullName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Телефон: \(app.phone) • ПИН: \(app.pin_code)")
                            .font(.system(size: 14))
                            .foregroundColor(AdminTheme.mint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AdminTheme.bgCard)
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("СТАРТОВЫЙ БАЛАНС ПРИ ОТКРЫТИИ (РУБ)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AdminTheme.textSecondary)
                        
                        TextField("50000", text: $initialBalanceString)
                            .keyboardType(.numberPad)
                            .font(.system(size: 22, weight: .black))
                            .padding()
                            .background(AdminTheme.bgCard)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                        
                        HStack(spacing: 8) {
                            quickBalanceButton("10 000 ₽", 10000)
                            quickBalanceButton("50 000 ₽", 50000)
                            quickBalanceButton("100 000 ₽", 100000)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await approveConfirmed(app) }
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Открыть счёт клиенту")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AdminTheme.mint)
                        .cornerRadius(16)
                    }
                    .disabled(isProcessing)
                }
                .padding(20)
            }
            .navigationTitle("Одобрение заявки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { appToApprove = nil }
                        .foregroundColor(AdminTheme.mint)
                }
            }
        }
    }
    
    private func quickBalanceButton(_ title: String, _ amt: Int) -> some View {
        Button(action: { initialBalanceString = "\(amt)" }) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AdminTheme.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AdminTheme.mint.opacity(0.12))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    private func loadData() async {
        isLoading = true
        do {
            let res = try await api.fetchApplications()
            await MainActor.run {
                applications = res
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func approveConfirmed(_ app: AdminApplication) async {
        isProcessing = true
        let bal = Double(initialBalanceString) ?? 50000.0
        do {
            try await api.approveApplication(id: app.id, initialBalance: bal)
            await MainActor.run {
                isProcessing = false
                appToApprove = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            await loadData()
        } catch {
            await MainActor.run {
                isProcessing = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    private func reject(_ app: AdminApplication) async {
        do {
            try await api.rejectApplication(id: app.id, reason: "Отклонено администратором")
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            await loadData()
        } catch {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
