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
    @State private var showContactsPicker: Bool = false
    
    let quickAmounts = [100, 500, 1000, 3000, 5000]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        // Contact Picker Shortcut Button
                        Button(action: { showContactsPicker = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(BankTheme.purpleGradient)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 19))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Перевод контактам")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Выбрать из телефонной книги (проверка в RoPay)")
                                        .font(.system(size: 12))
                                        .foregroundColor(BankTheme.textMuted)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(BankTheme.bgCard)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.mint.opacity(0.3), lineWidth: 1))
                        }
                        
                        // Recipient Phone Input Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("НОМЕР ТЕЛЕФОНА ПОЛУЧАТЕЛЯ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(BankTheme.textMuted)
                            
                            HStack {
                                TextField("+7 999 123-45-67", text: $recipientPhone)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .keyboardType(.phonePad)
                                    .onChange(of: recipientPhone) { newValue in
                                        lookupRecipient(phone: newValue)
                                    }
                                
                                Button(action: { showContactsPicker = true }) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(BankTheme.mint)
                                }
                            }
                            .padding()
                            .background(BankTheme.bgCard)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
                            
                            // Recipient Verified Pill
                            if isLookingUp {
                                HStack(spacing: 8) {
                                    ProgressView().tint(BankTheme.mint)
                                    Text("Поиск клиента в RoPay...")
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
                        
                        // Transfer Amount with Liquid Glass & +/- 1 ₽ Stepper
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("СУММА ПЕРЕВОДА")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(BankTheme.textMuted)
                                
                                Spacer()
                                
                                Text("Баланс: \(currentUser.formattedBalance)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(BankTheme.mint)
                            }
                            
                            // Liquid Glass Container with Stepper
                            LiquidGlassAmountView(amountString: $amountString)
                        }
                        
                        // Quick Amount Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(quickAmounts, id: \.self) { amt in
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                            amountString = "\(amt)"
                                        }
                                    }) {
                                        Text("+\(amt) ₽")
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
            .navigationTitle("Перевод клиенту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(BankTheme.mint)
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView { phone, name in
                    recipientPhone = phone
                    recipientName = name
                    lookupRecipient(phone: phone)
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
