import SwiftUI

// MARK: - Bank Brand Colors & Design Tokens
struct BankTheme {
    static let mint = Color(hex: "#00E599")
    static let purple = Color(hex: "#8E44AD")
    static let magenta = Color(hex: "#D81B60")
    static let bgDark = Color(hex: "#0D1117")
    static let bgDarkSecondary = Color(hex: "#12161D")
    static let bgCard = Color(hex: "#161B22")
    static let bgCardSecondary = Color(hex: "#1F242C")
    static let bgCardSubtle = Color(hex: "#21262D")
    static let border = Color(hex: "#30363D")
    static let textMuted = Color(hex: "#8B949E")
    static let danger = Color(hex: "#FF453A")
    static let textWhite = Color.white

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [mint, Color(hex: "#00B87A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let purpleGradient = LinearGradient(
        colors: [purple, magenta],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [bgCard, Color(hex: "#1A202C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Native Liquid Glass Modifiers
extension View {
    /// Нативный системный модификатор стекла Liquid Glass
    @ViewBuilder
    func glassEffect(cornerRadius: CGFloat = 32) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.65), location: 0.0),
                                .init(color: .white.opacity(0.18), location: 0.35),
                                .init(color: .clear, location: 0.70),
                                .init(color: .white.opacity(0.25), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}
