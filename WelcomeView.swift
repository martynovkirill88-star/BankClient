import SwiftUI

struct WelcomeView: View {
    let userName: String
    var onComplete: () -> Void
    
    @State private var cardOffset: CGFloat = -200
    @State private var cardOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            BankTheme.bgDark.ignoresSafeArea()
            
            // Background subtle glow
            VStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(BankTheme.mint.opacity(0.12))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkmark.fill")
                            .font(.system(size: 32))
                            .foregroundColor(BankTheme.mint)
                        
                        Text("Безопасное соединение установлено")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BankTheme.textMuted)
                    }
                }
                Spacer()
            }
            .opacity(backgroundOpacity)
            
            // Top Sliding Light Card (from IMG_5848.MP4)
            VStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ДОБРЫЙ ДЕНЬ,\n\(userName.uppercased())!")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.black)
                        .lineSpacing(4)
                    
                    HStack {
                        Text("RoPay")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .offset(y: cardOffset)
                .opacity(cardOpacity)
            }
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.easeIn(duration: 0.3)) {
                backgroundOpacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                cardOffset = 0
                cardOpacity = 1.0
            }
            
            // Auto-dismiss after 1.8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    cardOffset = -120
                    cardOpacity = 0
                    backgroundOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    onComplete()
                }
            }
        }
    }
}
