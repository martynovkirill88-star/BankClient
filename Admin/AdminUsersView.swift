import SwiftUI

struct AdminUsersView: View {
    @StateObject private var api = AdminAPIService.shared
    
    @State private var users: [AdminUser] = []
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""
    
    // Balance adjustment modal
    @State private var userToAdjust: AdminUser? = nil
    @State private var adjustAmountString: String = "10000"
    @State private var adjustReason: String = "Бонус администратора"
    @State private var isAdjusting: Bool = false
    
    var filteredUsers: [AdminUser] {
        if searchQuery.isEmpty { return users }
        let q = searchQuery.lowercased()
        return users.filter {
            $0.fullName.lowercased().contains(q) || ($0.phone?.contains(q) == true)
        }
    }
    
    var totalCirculating: Double {
        users.reduce(0.0) { $0 + $1.balance }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Stats Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ДЕНЬГИ В ОБРАЩЕНИИ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AdminTheme.textSecondary)
                            Text("\(Int(totalCirculating)) ₽")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(AdminTheme.mint)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("ВСЕГО КЛИЕНТОВ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AdminTheme.textSecondary)
                            Text("\(users.count)")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(16)
                    .background(AdminTheme.bgCard)
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AdminTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AdminTheme.textSecondary)
                        TextField("Поиск по имени или телефону...", text: $searchQuery)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(AdminTheme.bgCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    if isLoading && users.isEmpty {
                        Spacer()
                        ProgressView().tint(AdminTheme.mint)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredUsers) { user in
                                    userCard(user)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await loadUsers()
                        }
                    }
                }
            }
            .navigationTitle("Клиенты RoPay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadUsers() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AdminTheme.mint)
                    }
                }
            }
            .task {
                await loadUsers()
            }
            .sheet(item: $userToAdjust) { user in
                balanceAdjustSheet(user: user)
            }
        }
    }
    
    // MARK: - User Card
    private func userCard(_ user: AdminUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AdminTheme.mint.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AdminTheme.mint)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(user.fullName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(user.phone ?? "Без телефона")
                    .font(.system(size: 13))
                    .foregroundColor(AdminTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text(user.formattedBalance)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(AdminTheme.mint)
                
                Button(action: { userToAdjust = user }) {
                    Text("Баланс ±")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AdminTheme.gold)
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(AdminTheme.bgCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AdminTheme.border, lineWidth: 1))
    }
    
    // MARK: - Adjust Balance Sheet
    private func balanceAdjustSheet(user: AdminUser) -> some View {
        NavigationStack {
            ZStack {
                AdminTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.fullName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Текущий баланс: \(user.formattedBalance)")
                            .font(.system(size: 14))
                            .foregroundColor(AdminTheme.mint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AdminTheme.bgCard)
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("СУММА ИЗМЕНЕНИЯ (РУБ)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AdminTheme.textSecondary)
                        
                        TextField("10000", text: $adjustAmountString)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .black))
                            .padding()
                            .background(AdminTheme.bgCard)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                        
                        HStack(spacing: 8) {
                            presetButton("+10 000 ₽", 10000)
                            presetButton("+50 000 ₽", 50000)
                            presetButton("-5 000 ₽", -5000)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ПРИЧИНА ОПЕРАЦИИ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AdminTheme.textSecondary)
                        
                        TextField("Бонус администратора", text: $adjustReason)
                            .padding()
                            .background(AdminTheme.bgCard)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdminTheme.border, lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { Task { await applyAdjustment(user: user, isDeposit: false) } }) {
                            Text("Списать")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AdminTheme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AdminTheme.danger.opacity(0.15))
                                .cornerRadius(16)
                        }
                        
                        Button(action: { Task { await applyAdjustment(user: user, isDeposit: true) } }) {
                            Text("Начислить")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AdminTheme.mint)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Корректировка счёта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { userToAdjust = nil }
                        .foregroundColor(AdminTheme.mint)
                }
            }
        }
    }
    
    private func presetButton(_ title: String, _ amt: Int) -> some View {
        Button(action: { adjustAmountString = "\(abs(amt))" }) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(amt > 0 ? AdminTheme.mint : AdminTheme.danger)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((amt > 0 ? AdminTheme.mint : AdminTheme.danger).opacity(0.12))
                .cornerRadius(10)
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        do {
            let res = try await api.fetchUsers()
            await MainActor.run {
                users = res
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func applyAdjustment(user: AdminUser, isDeposit: Bool) async {
        guard let amt = Double(adjustAmountString), amt > 0 else { return }
        let delta = isDeposit ? amt : -amt
        do {
            _ = try await api.adjustBalance(userId: user.id, delta: delta, reason: adjustReason)
            await MainActor.run {
                userToAdjust = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            await loadUsers()
        } catch {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
