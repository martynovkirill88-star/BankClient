import SwiftUI
import AVKit
import Combine

enum CallState {
    case connecting
    case botSpeaking
    case waitingOperator
    case operatorActive
    case ended
}

struct SupportCallView: View {
    @Environment(\.dismiss) private var dismiss
    let chatId: Int
    let user: User?
    
    @State private var callId: Int? = nil
    @State private var callState: CallState = .connecting
    @State private var botMessageText: String = "Соединение с голосовым помощником RoPay..."
    @State private var isMuted: Bool = false
    @State private var isSpeaker: Bool = true
    @State private var callDurationSeconds: Int = 0
    
    // Audio Player
    @State private var player: AVPlayer? = nil
    
    // Wave pulsation animation
    @State private var pulseScale: CGFloat = 1.0
    @State private var waveAnimation: Bool = false
    
    // Timers
    private let durationTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private let statusPollTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Dark futuristic background
            BankTheme.bgDark.ignoresSafeArea()
            
            // Atmospheric glowing orbs
            RadialGradient(
                colors: [
                    (callState == .waitingOperator ? Color.yellow.opacity(0.18) : (callState == .operatorActive ? BankTheme.mint.opacity(0.2) : BankTheme.purple.opacity(0.25))),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Bar (Call status & Timer)
                VStack(spacing: 6) {
                    Text(callerTitle)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(callerSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                    
                    if callState == .operatorActive || callState == .botSpeaking {
                        Text(formattedDuration)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Pulsating Audio Visualizer Avatar
                ZStack {
                    // Outer pulse rings
                    Circle()
                        .stroke(statusColor.opacity(0.25), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                        .opacity(waveAnimation ? 0.0 : 0.8)
                    
                    Circle()
                        .stroke(statusColor.opacity(0.4), lineWidth: 2.5)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale * 0.95)
                    
                    // Central Circle Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BankTheme.bgCardSecondary, BankTheme.bgCard],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(Circle().stroke(statusColor, lineWidth: 2))
                        .shadow(color: statusColor.opacity(0.4), radius: 20, x: 0, y: 4)
                    
                    Image(systemName: centerIconName)
                        .font(.system(size: 46))
                        .foregroundColor(statusColor)
                }
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseScale)
                .onAppear {
                    pulseScale = 1.25
                    waveAnimation = true
                }
                
                // Bot Speech Transcript Box
                VStack(spacing: 8) {
                    if callState == .waitingOperator {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 14))
                                .foregroundColor(Color.yellow)
                            Text("Играет музыка ожидания... Соединяем со специалистом")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.yellow)
                        }
                    }
                    
                    Text(botMessageText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(BankTheme.bgCard.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(BankTheme.border, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                }
                
                // Interactive Speech Quick Actions
                if callState == .botSpeaking {
                    VStack(spacing: 8) {
                        Text("НАЖМИТЕ, ЧТОБЫ СКАЗАТЬ БОТУ:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                speechChip("🗣 Позвать оператора", "Оператор")
                                speechChip("🗣 Какой у меня баланс?", "Какой у меня баланс?")
                                speechChip("🗣 Как перевести деньги?", "Как перевести деньги?")
                                speechChip("🗣 Где банкоматы RoPay?", "Где банкоматы?")
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer()
                
                // Call Controls Bar
                HStack(spacing: 40) {
                    // Mute Button
                    Button(action: {
                        isMuted.toggle()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isMuted ? Color.white : BankTheme.bgCardSecondary)
                                    .frame(width: 60, height: 60)
                                    .overlay(Circle().stroke(BankTheme.border, lineWidth: 1))
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(isMuted ? .black : .white)
                            }
                            Text(isMuted ? "Вкл. звук" : "Выкл. микр")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(BankTheme.textMuted)
                        }
                    }
                    
                    // End Call Button (Big Red)
                    Button(action: endCall) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(BankTheme.danger)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: BankTheme.danger.opacity(0.5), radius: 12, x: 0, y: 4)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Завершить")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Speaker Button
                    Button(action: {
                        isSpeaker.toggle()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSpeaker ? Color.white : BankTheme.bgCardSecondary)
                                    .frame(width: 60, height: 60)
                                    .overlay(Circle().stroke(BankTheme.border, lineWidth: 1))
                                Image(systemName: isSpeaker ? "speaker.wave.3.fill" : "speaker.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(isSpeaker ? .black : .white)
                            }
                            Text("Динамик")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(BankTheme.textMuted)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await startCallSession()
        }
        .onReceive(durationTimer) { _ in
            if callState != .connecting && callState != .ended {
                callDurationSeconds += 1
            }
        }
        .onReceive(statusPollTimer) { _ in
            if callState == .waitingOperator, let cid = callId {
                Task {
                    let st = try? await APIService.shared.fetchCallStatus(callId: cid)
                    if st == "operator_active" {
                        await MainActor.run {
                            self.callState = .operatorActive
                            self.botMessageText = "Оператор подключился к диалогу. Вы на связи со специалистом банка!"
                            stopAudio()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } else if st == "ended" {
                        await MainActor.run { endCall() }
                    }
                }
            }
        }
        .onDisappear {
            stopAudio()
            if let cid = callId {
                APIService.shared.endSupportCall(callId: cid)
            }
        }
    }
    
    // MARK: - UI Helpers
    private var callerTitle: String {
        switch callState {
        case .connecting: return "Поддержка RoPay"
        case .botSpeaking: return "Бот-помощник"
        case .waitingOperator: return "Оператор RoPay"
        case .operatorActive: return "Оператор на связи"
        case .ended: return "Звонок завершён"
        }
    }
    
    private var callerSubtitle: String {
        switch callState {
        case .connecting: return "Соединение с банком..."
        case .botSpeaking: return "Голосовой ассистент RoPay"
        case .waitingOperator: return "Ожидание свободного оператора"
        case .operatorActive: return "Прямая линия поддержки"
        case .ended: return "Спасибо за обращение"
        }
    }
    
    private var statusColor: Color {
        switch callState {
        case .connecting: return BankTheme.textMuted
        case .botSpeaking: return BankTheme.mint
        case .waitingOperator: return Color.yellow
        case .operatorActive: return BankTheme.mint
        case .ended: return BankTheme.danger
        }
    }
    
    private var centerIconName: String {
        switch callState {
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .botSpeaking: return "brain.head.profile"
        case .waitingOperator: return "headphones"
        case .operatorActive: return "person.crop.circle.badge.checkmark"
        case .ended: return "phone.down.fill"
        }
    }
    
    private var formattedDuration: String {
        let mins = callDurationSeconds / 60
        let secs = callDurationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func speechChip(_ title: String, _ textToSend: String) -> some View {
        Button(action: {
            Task { await sendSpeech(textToSend) }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(BankTheme.bgCardSecondary)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(BankTheme.mint.opacity(0.6), lineWidth: 1))
        }
    }
    
    // MARK: - Call Logic
    private func startCallSession() async {
        guard let u = user else { return }
        do {
            let res = try await APIService.shared.startSupportCall(
                chatId: chatId,
                userId: u.id,
                userName: u.name,
                phone: u.phone ?? ""
            )
            await MainActor.run {
                self.callId = res.call_id
                self.callState = .botSpeaking
                if let msg = res.bot_message {
                    self.botMessageText = msg
                }
                if let audio = res.audio_url, let url = URL(string: audio) {
                    playAudio(url)
                }
            }
        } catch {
            await MainActor.run {
                self.botMessageText = "Не удалось соединиться с голосовым сервером."
            }
        }
    }
    
    private func sendSpeech(_ text: String) async {
        guard let cid = callId else { return }
        stopAudio()
        await MainActor.run {
            self.botMessageText = "Обработка запроса: «\(text)»..."
        }
        
        do {
            let res = try await APIService.shared.sendCallSpeech(callId: cid, speechText: text)
            await MainActor.run {
                if let msg = res.bot_message {
                    self.botMessageText = msg
                }
                
                if res.status == "waiting_operator" {
                    self.callState = .waitingOperator
                    if let audio = res.audio_url, let url = URL(string: audio) {
                        playAudio(url, loopAfter: "https://app.ropay.site/static/music/hold_music.wav")
                    }
                } else {
                    self.callState = .botSpeaking
                    if let audio = res.audio_url, let url = URL(string: audio) {
                        playAudio(url)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.botMessageText = "Ошибка связи. Попробуйте еще раз."
            }
        }
    }
    
    private func playAudio(_ url: URL, loopAfter: String? = nil) {
        stopAudio()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceChat)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        
        if let loop = loopAfter, let loopURL = URL(string: loop) {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                let loopItem = AVPlayerItem(url: loopURL)
                player?.replaceCurrentItem(with: loopItem)
                player?.play()
            }
        }
    }
    
    private func stopAudio() {
        player?.pause()
        player = nil
    }
    
    private func endCall() {
        stopAudio()
        if let cid = callId {
            APIService.shared.endSupportCall(callId: cid)
        }
        dismiss()
    }
}
