import SwiftUI

struct LiquidGlassAmountView: View {
    @Binding var amountString: String
    
    @State private var isPulsing: Bool = false
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.0
    @FocusState private var isInputFocused: Bool
    
    private var currentAmount: Int {
        Int(amountString.filter { $0.isNumber }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Ambient fluid colored glow behind the glass
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                BankTheme.mint.opacity(isPulsing ? 0.35 : 0.18),
                                BankTheme.purple.opacity(isPulsing ? 0.30 : 0.12),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .blur(radius: 20)
                
                // Frosted Liquid Glass Card Container
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        // Liquid ripple effect when stepping +/- 1 ₽
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(BankTheme.mint.opacity(rippleOpacity), lineWidth: 3)
                            .scaleEffect(rippleScale)
                    )
                    .overlay(
                        // Glass top reflection highlight
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    )
                    .overlay(
                        // Iridescent Glass Bevel Border
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        BankTheme.mint.opacity(0.7),
                                        BankTheme.purple.opacity(0.5),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                
                // Stepper and Amount Controls Inside the Glass
                HStack(spacing: 14) {
                    // Minus 1 ₽ Button
                    Button(action: { stepAmount(by: -1) }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            Image(systemName: "minus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(currentAmount > 0 ? BankTheme.mint : BankTheme.textMuted.opacity(0.4))
                        }
                    }
                    .buttonStyle(GlassScaleButtonStyle())
                    .disabled(currentAmount <= 0)
                    
                    // Amount Value & Hidden TextField for Keyboard Input
                    VStack(spacing: 2) {
                        ZStack {
                            // Invisible tap target to focus textfield
                            TextField("", text: $amountString)
                                .keyboardType(.numberPad)
                                .focused($isInputFocused)
                                .opacity(0.01)
                                .frame(width: 1, height: 1)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formattedDisplayAmount)
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .scaleEffect(isPulsing ? 1.08 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPulsing)
                                
                                Text("₽")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(BankTheme.mint)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isInputFocused = true
                            }
                        }
                        
                        Text(currentAmount == 0 ? "Нажмите для ввода суммы" : "Шаг регулировки: ±1 ₽")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(BankTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Plus 1 ₽ Button
                    Button(action: { stepAmount(by: 1) }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [BankTheme.mint.opacity(0.25), BankTheme.purple.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Circle()
                                        .stroke(BankTheme.mint.opacity(0.5), lineWidth: 1)
                                )
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(BankTheme.mint)
                        }
                    }
                    .buttonStyle(GlassScaleButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .frame(height: 96)
        }
    }
    
    private var formattedDisplayAmount: String {
        if amountString.isEmpty || currentAmount == 0 {
            return "0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: currentAmount)) ?? "\(currentAmount)"
    }
    
    private func stepAmount(by delta: Int) {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
        let newAmount = max(0, currentAmount + delta)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            amountString = newAmount == 0 ? "" : "\(newAmount)"
            triggerLiquidPulse()
        }
    }
    
    private func triggerLiquidPulse() {
        isPulsing = true
        rippleScale = 0.95
        rippleOpacity = 0.8
        
        withAnimation(.easeOut(duration: 0.45)) {
            rippleScale = 1.08
            rippleOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPulsing = false
            }
        }
    }
}

// Button Style with spring bounce for glass buttons
struct GlassScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
