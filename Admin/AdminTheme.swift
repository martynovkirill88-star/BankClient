import SwiftUI

// MARK: - Admin Theme
struct AdminTheme {
    static let bgDark = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let bgCard = Color(red: 0.09, green: 0.11, blue: 0.16)
    static let bgCardSecondary = Color(red: 0.12, green: 0.14, blue: 0.20)
    
    // Admin Accents: Royal Gold / Amber + Cyan / Mint
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.20)
    static let mint = Color(red: 0.00, green: 0.88, blue: 0.65)
    static let purple = Color(red: 0.60, green: 0.35, blue: 0.95)
    static let danger = Color(red: 1.00, green: 0.30, blue: 0.35)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let border = Color.white.opacity(0.12)
    
    static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 0.95, green: 0.65, blue: 0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mintGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.92, blue: 0.72), Color(red: 0.00, green: 0.75, blue: 0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
