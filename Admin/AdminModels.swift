import Foundation

// MARK: - Admin Models

struct AdminApplication: Codable, Identifiable {
    let id: Int
    let first_name: String
    let last_name: String
    let phone: String
    let pin_code: String
    let pin_hash: String?
    let telegram: String
    let status: String // "pending", "approved", "rejected"
    let admin_notes: String?
    let created_at: String?
    let reviewed_at: String?
    
    var fullName: String {
        "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
    }
    
    var telegramClean: String {
        telegram.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces)
    }
}

struct AdminStatusItem: Codable, Identifiable {
    let id: Int
    let title: String?
    let text: String?
    let media_url: String
    let media_filename: String?
    let media_type: String // "photo" or "video"
    let duration: Int?
    let target_platform: String? // "all", "ios", "android"
    let views_count: Int?
    let created_at: String?
    
    var platformBadge: String {
        switch target_platform {
        case "ios": return "📱 iPhone"
        case "android": return "🤖 Android"
        default: return "🌐 Все платформы"
        }
    }
}

struct AdminStats: Codable {
    let users_count: Int
    let total_balance: Double
    let total_transactions: Int
    let pending_applications: Int
    let active_statuses: Int
}

struct AdminUser: Codable, Identifiable {
    let id: Int
    let name: String
    let surname: String?
    let phone: String?
    let balance: Double
    let photo_filename: String?
    let created_at: String?
    
    var fullName: String {
        let sur = surname ?? ""
        return sur.isEmpty ? name : "\(name) \(sur)"
    }
    
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: balance)) ?? "\(Int(balance))"
        return "\(formatted) ₽"
    }
}

// API Responses
struct AdminStatsResponse: Codable {
    let success: Bool
    let stats: AdminStats
}

struct AdminApplicationsResponse: Codable {
    let success: Bool
    let applications: [AdminApplication]
}

struct AdminStatusesResponse: Codable {
    let success: Bool
    let statuses: [AdminStatusItem]
}

struct AdminUsersResponse: Codable {
    let success: Bool
    let users: [AdminUser]
}
