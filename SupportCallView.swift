import SwiftUI
import AVKit
import Speech
import Combine

enum CallState {
    case connecting
    case botSpeaking
    case listeningToUser
    case waitingOperator
    case operatorActive
    case ended
}

// MARK: - Real-Time Speech Recognizer for Voice Call
class CallSpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var isAuthorized: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var silenceTimer: Timer?
    var onSpeechFinished: ((String) -> Void)?
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    
    func startListening() {
        guard !audioEngine.isRunning else { return }
        stopListening()
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
        transcript = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let spokenText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.transcript = spokenText
                }
                
                // Silence detection: reset timer on every spoken syllable/word
                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
                    guard let self = self, !spokenText.isEmpty else { return }
                    self.stopListening()
                    self.onSpeechFinished?(spokenText)
                }
            }
            
            if error != nil {
                self.stopListening()
            }
        }
    }
    
    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
}

// MARK: - Support Call View
struct SupportCallView: View {
    @Environment(\.dismiss) private var dismiss
    let chatId: Int
    let user: User?
    
    @StateObject private var recognizer = CallSpeechRecognizer()
    
    @State private var callId: Int? = nil
    @State private var callState: CallState = .connecting
    @State private var botSpokenText: String = "Соединение с поддержкой..."
    @State private var userSpokenText: String = ""
    @State private var isMuted: Bool = false
    @State private var isSpeaker: Bool = true
    @State private var callDurationSeconds: Int = 0
    
    // Audio Player
    @State private var player: AVPlayer? = nil
    
    // Wave animation phases
    @State private var wavePhase: CGFloat = 0
    @State private var soundLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3]
    
    // Timers
    private let durationTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private let statusPollTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    private let waveTimer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Dark elegant background
            BankTheme.bgDark.ignoresSafeArea()
            
            // Atmospheric soft ambient glow
            RadialGradient(
                colors: [ambientGlowColor.opacity(0.22), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 260
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header (Strictly "Поддержка" as requested)
                VStack(spacing: 6) {
                    Text("Поддержка")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(callStatusSubtext)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(statusColor)
                    
                    if callState != .connecting && callState != .ended {
                        Text(formattedDuration)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BankTheme.textMuted)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Sleek Center Support Avatar & Live Soundwave
                VStack(spacing: 20) {
                    ZStack {
                        // Soft outer pulsating aura
                        Circle()
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 140, height: 140)
                            .scaleEffect(callState == .botSpeaking || recognizer.isListening ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: callState)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BankTheme.bgCardSecondary, BankTheme.bgCard],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .overlay(Circle().stroke(statusColor.opacity(0.6), lineWidth: 2))
                            .shadow(color: statusColor.opacity(0.35), radius: 16, x: 0, y: 4)
                        
                        Image(systemName: centerIcon)
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    
                    // Live Soundwave Bars
                    HStack(spacing: 5) {
                        ForEach(0..<soundLevels.count, id: \.self) { idx in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(statusColor)
                                .frame(width: 4, height: max(6, soundLevels[idx] * 40))
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: soundLevels[idx])
                        }
                    }
                    .frame(height: 44)
                }
                
                // Live Conversation Card (Shows what the user says and what the bot replies)
                VStack(spacing: 10) {
                    if !userSpokenText.isEmpty {
                        HStack(spacing: 6) {
                            Text("Вы:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                            Text(userSpokenText)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(BankTheme.mint.opacity(0.12))
                        .cornerRadius(12)
                    }
                    
                    Text(botSpokenText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(BankTheme.bgCard.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(callState == .waitingOperator ? Color.yellow.opacity(0.5) : BankTheme.border, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Bottom Call Controls Bar
                HStack(spacing: 36) {
                    // Mute Button
                    Button(action: toggleMute) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isMuted ? Color.white : BankTheme.bgCardSecondary)
                                    .frame(width: 62, height: 62)
                                    .overlay(Circle().stroke(BankTheme.border, lineWidth: 1))
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(isMuted ? .black : .white)
                            }
                            Text(isMuted ? "Вкл. микр" : "Без звука")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(BankTheme.textMuted)
                        }
                    }
                    
                    // End Call Button (Big Red Circle)
                    Button(action: endCall) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(BankTheme.danger)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: BankTheme.danger.opacity(0.55), radius: 14, x: 0, y: 4)
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
                    Button(action: toggleSpeaker) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSpeaker ? Color.white : BankTheme.bgCardSecondary)
                                    .frame(width: 62, height: 62)
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
            setupSpeechHandler()
            await startCallSession()
        }
        .onReceive(durationTimer) { _ in
            if callState != .connecting && callState != .ended {
                callDurationSeconds += 1
            }
        }
        .onReceive(waveTimer) { _ in
            updateSoundLevels()
        }
        .onReceive(statusPollTimer) { _ in
            if callState == .waitingOperator, let cid = callId {
                Task {
                    let st = try? await APIService.shared.fetchCallStatus(callId: cid)
                    if st == "operator_active" {
                        await MainActor.run {
                            self.callState = .operatorActive
                            self.botSpokenText = "Оператор подключился к диалогу. Вы на связи со специалистом банка!"
                            stopAudio()
                            recognizer.startListening()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } else if st == "ended" {
                        await MainActor.run { endCall() }
                    }
                }
            }
        }
        .onReceive(recognizer.$transcript) { liveText in
            if !liveText.isEmpty {
                self.userSpokenText = liveText
            }
        }
        .onDisappear {
            recognizer.stopListening()
            stopAudio()
            if let cid = callId {
                APIService.shared.endSupportCall(callId: cid)
            }
        }
    }
    
    // MARK: - UI Attributes
    private var callStatusSubtext: String {
        switch callState {
        case .connecting: return "Соединение с сервером банка..."
        case .botSpeaking: return "Бот-помощник отвечает..."
        case .listeningToUser: return "Слушаю вас... Говорите"
        case .waitingOperator: return "Ожидание свободного оператора..."
        case .operatorActive: return "Оператор на связи"
        case .ended: return "Звонок завершён"
        }
    }
    
    private var statusColor: Color {
        switch callState {
        case .connecting: return BankTheme.textMuted
        case .botSpeaking: return BankTheme.mint
        case .listeningToUser: return Color(hex: "#00E599")
        case .waitingOperator: return Color.yellow
        case .operatorActive: return BankTheme.mint
        case .ended: return BankTheme.danger
        }
    }
    
    private var ambientGlowColor: Color {
        switch callState {
        case .waitingOperator: return Color.yellow
        case .operatorActive: return BankTheme.mint
        default: return BankTheme.purple
        }
    }
    
    private var centerIcon: String {
        switch callState {
        case .connecting: return "phone.arrow.up.right"
        case .botSpeaking: return "waveform"
        case .listeningToUser: return "mic.fill"
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
    
    private func updateSoundLevels() {
        if callState == .botSpeaking || recognizer.isListening {
            soundLevels = (0..<7).map { _ in CGFloat.random(in: 0.15...0.95) }
        } else {
            soundLevels = [0.1, 0.1, 0.15, 0.1, 0.15, 0.1, 0.1]
        }
    }
    
    // MARK: - Speech & Call Handling
    private func setupSpeechHandler() {
        recognizer.onSpeechFinished = { [self] spokenText in
            guard !isMuted else { return }
            Task {
                await processUserVoice(spokenText)
            }
        }
    }
    
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
                    self.botSpokenText = msg
                }
                if let audio = res.audio_url, let url = URL(string: audio) {
                    playAudio(url) {
                        // When initial greeting ends, start listening to user!
                        recognizer.startListening()
                        self.callState = .listeningToUser
                    }
                } else {
                    recognizer.startListening()
                    self.callState = .listeningToUser
                }
            }
        } catch {
            await MainActor.run {
                self.botSpokenText = "Не удалось соединиться с голосовым сервером."
            }
        }
    }
    
    private func processUserVoice(_ text: String) async {
        guard let cid = callId else { return }
        stopAudio()
        
        await MainActor.run {
            self.userSpokenText = text
            self.botSpokenText = "Обработка вашего вопроса..."
            self.callState = .botSpeaking
        }
        
        do {
            let res = try await APIService.shared.sendCallSpeech(callId: cid, speechText: text)
            await MainActor.run {
                if let msg = res.bot_message {
                    self.botSpokenText = msg
                }
                
                if res.status == "waiting_operator" {
                    self.callState = .waitingOperator
                    if let audio = res.audio_url, let url = URL(string: audio) {
                        playAudio(url, loopAfter: "https://app.ropay.site/static/music/hold_music.wav")
                    }
                } else {
                    self.callState = .botSpeaking
                    if let audio = res.audio_url, let url = URL(string: audio) {
                        playAudio(url) {
                            // After bot answers, resume listening for the user's next question!
                            recognizer.startListening()
                            self.callState = .listeningToUser
                        }
                    } else {
                        recognizer.startListening()
                        self.callState = .listeningToUser
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.botSpokenText = "Повторите, пожалуйста, вас не было слышно."
                recognizer.startListening()
                self.callState = .listeningToUser
            }
        }
    }
    
    private func playAudio(_ url: URL, loopAfter: String? = nil, onFinished: (() -> Void)? = nil) {
        stopAudio()
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            if let loop = loopAfter, let loopURL = URL(string: loop) {
                let loopItem = AVPlayerItem(url: loopURL)
                player?.replaceCurrentItem(with: loopItem)
                player?.play()
            } else {
                onFinished?()
            }
        }
    }
    
    private func stopAudio() {
        player?.pause()
        player = nil
    }
    
    private func toggleMute() {
        isMuted.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isMuted {
            recognizer.stopListening()
        } else if callState == .listeningToUser {
            recognizer.startListening()
        }
    }
    
    private func toggleSpeaker() {
        isSpeaker.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let audioSession = AVAudioSession.sharedInstance()
        let port: AVAudioSession.PortOverride = isSpeaker ? .speaker : .none
        try? audioSession.overrideOutputAudioPort(port)
    }
    
    private func endCall() {
        recognizer.stopListening()
        stopAudio()
        callState = .ended
        if let cid = callId {
            APIService.shared.endSupportCall(callId: cid)
        }
        dismiss()
    }
}
