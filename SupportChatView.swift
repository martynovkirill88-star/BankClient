import SwiftUI
import Combine

struct SupportChatView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User?
    
    @State private var chat: SupportChat? = nil
    @State private var messages: [SupportMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = true
    @State private var isSending: Bool = false
    @State private var showCallView: Bool = false
    
    // Auto-poll messages every 2.5 seconds
    private let pollTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                BankTheme.bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header Bar
                    headerBar
                    
                    // Messages Scroll Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { msg in
                                    messageBubble(msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .onChange(of: messages.count) { _ in
                            if let last = messages.last {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Quick Action Suggestion Chips
                    quickChipsBar
                    
                    // Bottom Message Input Bar
                    inputBar
                }
            }
            .navigationBarHidden(true)
            .task {
                await initChat()
            }
            .onReceive(pollTimer) { _ in
                if let c = chat {
                    Task { await pollMessages(chatId: c.id) }
                }
            }
            .fullScreenCover(isPresented: $showCallView) {
                if let c = chat {
                    SupportCallView(chatId: c.id, user: user)
                }
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(BankTheme.bgCardSecondary)
                    .clipShape(Circle())
            }
            
            ZStack {
                Circle()
                    .fill(BankTheme.mint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 19))
                    .foregroundColor(BankTheme.mint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Бот-помощник")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(BankTheme.mint)
                        .frame(width: 7, height: 7)
                    Text("RoPay Support • Отвечает мгновенно")
                        .font(.system(size: 11))
                        .foregroundColor(BankTheme.textMuted)
                }
            }
            
            Spacer()
            
            // Audio Call Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCallView = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Звонок")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [BankTheme.mint, Color.yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: BankTheme.mint.opacity(0.35), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(BankTheme.bgDarkSecondary)
        .overlay(Divider().background(BankTheme.border), alignment: .bottom)
    }
    
    // MARK: - Message Bubble
    private func messageBubble(_ msg: SupportMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                // Sender title tag
                if !msg.isUser {
                    HStack(spacing: 5) {
                        Image(systemName: msg.isOperator ? "person.crop.circle.badge.checkmark" : "sparkles")
                            .font(.system(size: 11))
                        Text(msg.sender_name ?? (msg.isOperator ? "Оператор RoPay" : "Бот-помощник"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(msg.isOperator ? Color.yellow : BankTheme.mint)
                    .padding(.leading, 4)
                }
                
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        msg.isUser
                            ? LinearGradient(colors: [BankTheme.mint.opacity(0.85), BankTheme.purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : (msg.isOperator
                               ? LinearGradient(colors: [Color.yellow.opacity(0.2), BankTheme.bgCardSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                               : LinearGradient(colors: [BankTheme.bgCard, BankTheme.bgCardSecondary], startPoint: .top, endPoint: .bottom))
                    )
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                msg.isUser ? Color.clear : (msg.isOperator ? Color.yellow.opacity(0.5) : BankTheme.border),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: msg.isUser ? BankTheme.mint.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
            }
            
            if !msg.isUser { Spacer(minLength: 40) }
        }
    }
    
    // MARK: - Quick Chips Bar
    private var quickChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("💳 Мой баланс", "Какой у меня баланс?")
                quickChip("⚡ Как перевести?", "Как сделать перевод?")
                quickChip("🏧 Банкоматы RoPay", "Где банкоматы RoPay?")
                quickChip("👤 Позвать оператора", "Позови оператора")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(BankTheme.bgDarkSecondary.opacity(0.6))
    }
    
    private func quickChip(_ title: String, _ prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(BankTheme.bgCardSecondary)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(BankTheme.border, lineWidth: 1))
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Напишите вопрос боту...", text: $inputText)
                .padding(12)
                .background(BankTheme.bgCard)
                .cornerRadius(16)
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BankTheme.border, lineWidth: 1))
            
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? BankTheme.bgCardSecondary
                                : BankTheme.mint
                        )
                        .frame(width: 44, height: 44)
                    
                    if isSending {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(
                                inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? BankTheme.textMuted
                                    : .black
                            )
                    }
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(BankTheme.bgDarkSecondary)
    }
    
    // MARK: - Logic
    private func initChat() async {
        guard let u = user else { return }
        isLoading = true
        do {
            let (c, m) = try await APIService.shared.initSupportChat(
                userId: u.id,
                userName: u.name,
                phone: u.phone ?? ""
            )
            await MainActor.run {
                self.chat = c
                self.messages = m
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func pollMessages(chatId: Int) async {
        do {
            let m = try await APIService.shared.fetchSupportMessages(chatId: chatId)
            await MainActor.run {
                self.messages = m
            }
        } catch {}
    }
    
    private func sendMessage() {
        let textToSend = inputText.trimmingCharacters(in: .whitespaces)
        guard !textToSend.isEmpty, let c = chat, let u = user else { return }
        
        inputText = ""
        isSending = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Optimistic append of user message
        let tempUserMsg = SupportMessage(
            id: Int.random(in: 1000000...9999999),
            chat_id: c.id,
            sender: "user",
            sender_name: "Клиент",
            text: textToSend,
            audio_url: nil,
            created_at: nil
        )
        messages.append(tempUserMsg)
        
        Task {
            do {
                let (_, botMsg, _) = try await APIService.shared.sendSupportMessage(
                    chatId: c.id,
                    userId: u.id,
                    text: textToSend
                )
                await MainActor.run {
                    self.isSending = false
                    if let b = botMsg {
                        self.messages.append(b)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}
