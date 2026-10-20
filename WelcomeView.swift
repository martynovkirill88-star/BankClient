import SwiftUI

struct WelcomeView: View {
    let userName: String
    var onComplete: () -> Void
    
    @State private var cardOffset: CGFloat = -180
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var shineOffset: CGFloat = -200
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            BankTheme.bgDark.ignoresSafeArea()
            
            // Background subtle glows
            VStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [BankTheme.mint.opacity(0.18), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 50)
                    
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(BankTheme.mint.opacity(0.15))
                                .frame(width: 64, height: 64)
                                .scaleEffect(isPulsing ? 1.15 : 1.0)
                                .opacity(isPulsing ? 0.6 : 1.0)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                            
                            Image(systemName: "shield.checkmark.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                        }
                        
                        Text("Безопасное соединение с RoPay")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(BankTheme.mint)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isPulsing ? 1.3 : 0.8)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                            
                            Text("Подключение к серверу...")
                                .font(.system(size: 12))
                                .foregroundColor(BankTheme.textMuted)
                        }
                    }
                }
                Spacer()
            }
            .opacity(backgroundOpacity)
            
            // Top Sliding Luxury White Card
            VStack {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ДОБРЫЙ ДЕНЬ,")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.55))
                            .tracking(2)
                        
                        Text(userName.uppercased())
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.black)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(BankTheme.mint)
                            Text("RoPay ID")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(10)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.black)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        Color.white
                        
                        // Diagonal shine highlight
                        LinearGradient(
                            colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .offset(x: shineOffset)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 12)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .offset(y: cardOffset)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
            }
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            isPulsing = true
            
            withAnimation(.easeOut(duration: 0.35)) {
                backgroundOpacity = 1.0
            }
            
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                cardOffset = 0
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                shineOffset = 300
            }
            
            // Auto-dismiss after 1.5 seconds smoothly to Dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    cardOffset = -120
                    cardOpacity = 0
                    cardScale = 0.94
                    backgroundOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onComplete()
                }
            }
        }
    }
}
