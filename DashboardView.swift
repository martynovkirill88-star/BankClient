import SwiftUI

struct DashboardView: View {
    @Binding var currentUser: User?
    var onLock: () -> Void
    
    @StateObject private var btManager = BluetoothManager.shared
    @State private var transactions: [BankTransaction] = []
    @State private var isLoadingTransactions: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var showAtmSheet: Bool = false
    @State private var isBalanceHidden: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // User Header Bar
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
                                
                                Text("Активный счёт")
                                    .font(.system(size: 12))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            
                            Spacer()
                            
                            // Refresh & Lock Buttons
                            HStack(spacing: 8) {
                                Button(action: refreshData) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(BankTheme.textMuted)
                                        .padding(10)
                                        .background(BankTheme.bgCard)
                                        .clipShape(Circle())
                                }
                                
                                Button(action: onLock) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(BankTheme.textMuted)
                                        .padding(10)
                                        .background(BankTheme.bgCard)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Phone Number Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("МОЙ НОМЕР ДЛЯ ПЕРЕВОДОВ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(BankTheme.textMuted)
                            
                            HStack {
                                Text(currentUser?.phone ?? "+7 (999) 000-00-00")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: copyPhone) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(BankTheme.mint)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BankTheme.bgCard)
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(BankTheme.border, lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Account Balance Card
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
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(BankTheme.mint.opacity(0.12))
                                    .cornerRadius(8)
                            }
                            
                            Text(isBalanceHidden ? "•••••• ₽" : (currentUser?.formattedBalance ?? "0 ₽"))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.white)
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button(action: { showTransferSheet = true }) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Перевести")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(BankTheme.mint)
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                                }
                                
                                Button(action: { showAtmSheet = true }) {
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                        Text("В банкомат")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(BankTheme.bgCardSubtle)
                                    .foregroundColor(BankTheme.purple)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BankTheme.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(20)
                        .background(BankTheme.cardGradient)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(BankTheme.border, lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Contactless Bluetooth Quick Banner
                        Button(action: { showAtmSheet = true }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(btManager.isAtmNearby ? BankTheme.mint.opacity(0.18) : BankTheme.purple.opacity(0.18))
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
                            .background(BankTheme.bgCard)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(btManager.isAtmNearby ? BankTheme.mint : BankTheme.border, lineWidth: btManager.isAtmNearby ? 1.5 : 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Transactions Section
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
                                        .background(BankTheme.bgCard)
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
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
            .onAppear {
                btManager.startScanning()
                loadTransactions()
            }
        }
    }
    
    private var userInitial: String {
        guard let name = currentUser?.name, let first = name.first else {
            return "К"
        }
        return String(first).uppercased()
    }
    
    private func copyPhone() {
        guard let phone = currentUser?.phone else { return }
        UIPasteboard.general.string = phone
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func refreshData() {
        guard let user = currentUser else { return }
        Task {
            do {
                let updated = try await APIService.shared.fetchProfile(userId: user.id)
                await MainActor.run {
                    currentUser = updated
                    loadTransactions()
                }
            } catch {
                print("Failed to refresh profile: \(error)")
            }
        }
    }
    
    private func loadTransactions() {
        guard let user = currentUser else { return }
        isLoadingTransactions = true
        Task {
            do {
                let list = try await APIService.shared.fetchTransactions(userId: user.id)
                await MainActor.run {
                    isLoadingTransactions = false
                    transactions = list
                }
            } catch {
                await MainActor.run {
                    isLoadingTransactions = false
                }
            }
        }
    }
}
