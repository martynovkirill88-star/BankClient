import SwiftUI

struct TransferView: View {
    let currentUser: User
    var onTransferCompleted: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var recipientPhone: String = "+7"
    @State private var recipientName: String? = nil
    @State private var isLookingUp: Bool = false
    @State private var amountString: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    let quickAmounts = [100, 500, 1000, 3000, 5000]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Recipient Phone Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("НОМЕР ТЕЛЕФОНА ПОЛУЧАТЕЛЯ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(BankTheme.textMuted)
                            
                            TextField("+7 999 123-45-67", text: $recipientPhone)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(BankTheme.bgCard)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
                                .onChange(of: recipientPhone) { newValue in
                                    lookupRecipient(phone: newValue)
                                }
                            
                            // Recipient Verified Pill
                            if isLookingUp {
                                HStack(spacing: 8) {
                                    ProgressView().tint(BankTheme.mint)
                                    Text("Поиск клиента...")
                                        .font(.system(size: 13))
                                        .foregroundColor(BankTheme.textMuted)
                                }
                                .padding(.top, 4)
                            } else if let name = recipientName {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(BankTheme.mint)
                                    Text("Получатель: \(name)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(BankTheme.mint)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(BankTheme.mint.opacity(0.12))
                                .cornerRadius(12)
                                .padding(.top, 4)
                            }
                        }
                        
                        // Transfer Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("СУММА ПЕРЕВОДА (₽)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(BankTheme.textMuted)
                            
                            TextField("0 ₽", text: $amountString)
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(BankTheme.bgCard)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
                        }
                        
                        // Quick Amount Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(quickAmounts, id: \.self) { amt in
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        amountString = "\(amt)"
                                    }) {
                                        Text("\(amt) ₽")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(BankTheme.bgCardSubtle)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BankTheme.border, lineWidth: 1))
                                    }
                                }
                            }
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BankTheme.danger)
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: submitTransfer) {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Подтвердить перевод")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BankTheme.mint)
                        .cornerRadius(16)
                        .disabled(isLoading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Перевод по номеру")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
        }
    }
    
    private func lookupRecipient(phone: String) {
        guard phone.count >= 8 else {
            recipientName = nil
            return
        }
        
        isLookingUp = true
        Task {
            do {
                let res = try await APIService.shared.lookupPhone(phone: phone)
                await MainActor.run {
                    isLookingUp = false
                    recipientName = res.found ? res.display_name : nil
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    recipientName = nil
                }
            }
        }
    }
    
    private func submitTransfer() {
        guard let amount = Double(amountString), amount > 0 else {
            errorMessage = "Укажите корректную сумму"
            return
        }
        guard amount <= currentUser.balance else {
            errorMessage = "Недостаточно средств на балансе"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let newBalance = try await APIService.shared.transferFunds(
                    senderId: currentUser.id,
                    recipientPhone: recipientPhone,
                    amount: amount
                )
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onTransferCompleted(newBalance)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
