import SwiftUI

struct LiquidGlassAmountView: View {
    @Binding var amountString: String
    
    @State private var isCountingDown: Bool = false
    @State private var previousAmount: Int = 0
    @FocusState private var isInputFocused: Bool
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var currentAmount: Int {
        Int(amountString.filter { $0.isNumber }) ?? 0
    }
    
    var body: some View {
        ZStack {
            // 1. Authentic Liquid Glass Container from iOS App
            GlassContainerBackground(cornerRadius: 24)
            
            // 2. Stepper and Amount Controls Inside the Glass
            HStack(spacing: 16) {
                // Minus 1 ₽ Glass Button
                Button(action: {
                    stepAmount(by: -1)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(currentAmount > 0 ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SystemGlassCircleButtonStyle(accent: .pink, isDisabled: currentAmount <= 0))
                .disabled(currentAmount <= 0)
                
                // Rolling Numeric Text with Native iOS Transition (.numericText)
                VStack(spacing: 2) {
                    ZStack {
                        // Invisible TextField for direct keyboard entry
                        TextField("", text: $amountString)
                            .keyboardType(.numberPad)
                            .focused($isInputFocused)
                            .opacity(0.01)
                            .frame(width: 1, height: 1)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(currentAmount)")
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: BankTheme.mint.opacity(0.4), radius: 15)
                                .contentTransition(.numericText(countsDown: isCountingDown))
                            
                            Text("₽")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(BankTheme.mint)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = true
                        }
                    }
                    
                    Text(currentAmount == 0 ? "Нажмите для ввода суммы" : "Шаг регулировки: ±1 ₽")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                
                // Plus 1 ₽ Glass Button
                Button(action: {
                    stepAmount(by: 1)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SystemGlassCircleButtonStyle(accent: BankTheme.mint, isDisabled: false))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(height: 94)
        .onChange(of: amountString) { newValue in
            let newAmount = Int(newValue.filter { $0.isNumber }) ?? 0
            isCountingDown = newAmount < previousAmount
            previousAmount = newAmount
        }
    }
    
    private func stepAmount(by delta: Int) {
        impactFeedback.impactOccurred()
        
        let newAmount = max(0, currentAmount + delta)
        isCountingDown = delta < 0
        previousAmount = newAmount
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            amountString = newAmount == 0 ? "" : "\(newAmount)"
        }
    }
}

// MARK: - Authentic Glass Container Background (from iOS App project)
struct GlassContainerBackground: View {
    var cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // 1. Фирменный блюр iOS
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // 2. Полупрозрачное молочно-стеклянное тело (пропускает свет сзади!)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.18), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.3),
                            .init(color: Color.clear, location: 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. Верхний скошенный световой блик (Specular Reflection)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.7), location: 0.0),
                            .init(color: Color.white.opacity(0.2), location: 0.25),
                            .init(color: Color.white.opacity(0.05), location: 0.6),
                            .init(color: Color.white.opacity(0.3), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Glass Circle Button Style with Real Press Depth (from iOS App project)
struct SystemGlassCircleButtonStyle: ButtonStyle {
    let accent: Color
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    
                    // Glass Accent Glow
                    Circle()
                        .fill(accent.opacity(isDisabled ? 0.05 : (configuration.isPressed ? 0.40 : 0.22)))
                    
                    // Glass Top Highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(configuration.isPressed ? 0.2 : 0.45), location: 0.0),
                                    .init(color: Color.clear, location: 0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                    
                    // Glass Edge Stroke
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(configuration.isPressed ? 0.4 : 0.75),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.1
                        )
                }
            )
            .clipShape(Circle())
            .shadow(color: isDisabled ? Color.clear : accent.opacity(configuration.isPressed ? 0.1 : 0.3), radius: 8, y: 3)
            .shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
