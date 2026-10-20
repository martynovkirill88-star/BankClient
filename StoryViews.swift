import SwiftUI
import AVKit
import Combine

// MARK: - Status Square Item (Preview on Dashboard)
struct StatusSquareItem: View {
    let status: BankStatus
    let isViewed: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background & Thumbnail Media
                ZStack {
                    BankTheme.bgCard
                    
                    if let url = URL(string: status.media_url), !status.media_url.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty:
                                ProgressView()
                                    .tint(BankTheme.mint)
                            default:
                                fallbackPlaceholder
                            }
                        }
                    } else {
                        fallbackPlaceholder
                    }
                }
                .frame(width: 76, height: 76)
                .clipped()
                
                // Bottom Gradient Scrim
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 38)
                
                // Title / Preview Text
                Text(status.title?.isEmpty == false ? status.title! : "RoPay")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(6)
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isViewed
                            ? LinearGradient(colors: [Color.white.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(
                                colors: [BankTheme.mint, Color.yellow, BankTheme.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isViewed ? 1.5 : 2.5
                    )
            )
            .shadow(
                color: isViewed ? Color.clear : BankTheme.mint.opacity(0.4),
                radius: 4, x: 0, y: 2
            )
            .opacity(isViewed ? 0.72 : 1.0)
        }
        .buttonStyle(ScaleTouchButtonStyle())
    }
    
    private var fallbackPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [BankTheme.mint.opacity(0.2), BankTheme.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: status.media_type == "video" ? "play.circle.fill" : "sparkles")
                .font(.system(size: 22))
                .foregroundColor(BankTheme.mint)
        }
    }
}

// MARK: - Scale Touch Button Style
struct ScaleTouchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Fullscreen Story / Status Viewer
struct StoryViewer: View {
    let initialStatus: BankStatus
    let statuses: [BankStatus]
    var onStatusViewed: (Int) -> Void
    var onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var progress: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var player: AVPlayer? = nil
    
    // Timer interval (50ms ticks for smooth progress bar)
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var currentStatus: BankStatus? {
        guard currentIndex >= 0 && currentIndex < statuses.count else { return nil }
        return statuses[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let status = currentStatus {
                // Media Content: Video or Photo
                ZStack {
                    if status.media_type == "video" {
                        if let pl = player {
                            VideoPlayer(player: pl)
                                .ignoresSafeArea()
                                .disabled(true)
                        } else {
                            ProgressView().tint(.white)
                        }
                    } else {
                        if let url = URL(string: status.media_url) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                case .empty:
                                    ProgressView().tint(.white)
                                default:
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .font(.system(size: 40))
                                            .foregroundColor(BankTheme.textMuted)
                                        Text("Не удалось загрузить фото")
                                            .font(.system(size: 14))
                                            .foregroundColor(BankTheme.textMuted)
                                    }
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 40, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.height > 80 {
                                dismissViewer()
                            }
                        }
                )
                .overlay(
                    // Tap detection for Next / Previous / Pause
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                previousStory()
                            }
                        
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                nextStory()
                            }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .onEnded { _ in isPaused = true }
                    )
                )
                
                // Top Overlay: Progress Bars + Header
                VStack(spacing: 12) {
                    // Segmented Progress Bars
                    HStack(spacing: 4) {
                        ForEach(0..<statuses.count, id: \.self) { idx in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.35))
                                    
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(
                                            width: idx < currentIndex ? geo.size.width : (idx == currentIndex ? geo.size.width * CGFloat(progress) : 0)
                                        )
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Header Bar (Avatar, Title, Date, Close Button)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(BankTheme.mint.opacity(0.2))
                                .frame(width: 38, height: 38)
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.title?.isEmpty == false ? status.title! : "RoPay Банк")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("История банка RoPay")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                        
                        Spacer()
                        
                        Button(action: dismissViewer) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Bottom Caption (без плашки блюра, прижат к нижнему краю экрана)
                    if let text = status.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(text)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.9), radius: 3, x: 0, y: 1)
                            .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 2)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .onAppear {
            if let idx = statuses.firstIndex(where: { $0.id == initialStatus.id }) {
                currentIndex = idx
            }
            startCurrentStory()
        }
        .onDisappear {
            stopCurrentStory()
        }
        .onReceive(timer) { _ in
            guard !isPaused, let status = currentStatus else { return }
            
            let totalDuration = Double(status.duration ?? 10)
            let step = 0.05 / max(totalDuration, 1.0)
            
            if progress + step >= 1.0 {
                progress = 1.0
                nextStory()
            } else {
                progress += step
            }
        }
    }
    
    private func startCurrentStory() {
        guard let status = currentStatus else { return }
        progress = 0.0
        onStatusViewed(status.id)
        
        if status.media_type == "video", let url = URL(string: status.media_url) {
            player = AVPlayer(url: url)
            player?.play()
        } else {
            player?.pause()
            player = nil
        }
    }
    
    private func stopCurrentStory() {
        player?.pause()
        player = nil
    }
    
    private func nextStory() {
        stopCurrentStory()
        if currentIndex + 1 < statuses.count {
            currentIndex += 1
            startCurrentStory()
        } else {
            dismissViewer()
        }
    }
    
    private func previousStory() {
        stopCurrentStory()
        if currentIndex > 0 {
            currentIndex -= 1
            startCurrentStory()
        } else {
            startCurrentStory()
        }
    }
    
    private func dismissViewer() {
        stopCurrentStory()
        onDismiss()
    }
}
