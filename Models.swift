import Foundation

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: Int
    var name: String
    var surname: String?
    var phone: String?
    var balance: Double
    var photo_filename: String?
    var has_face: Bool?
    var created_at: String?
    
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

// MARK: - Transaction Model
struct BankTransaction: Codable, Identifiable {
    let id: Int
    let user_id: Int?
    let user_name: String?
    let type: String
    let amount: Double
    let balance_after: Double
    let details: String?
    let created_at: String?
    
    var isPositive: Bool {
        type == "DEPOSIT" || type == "TRANSFER_IN"
    }
    
    var title: String {
        switch type {
        case "DEPOSIT":
            return "Пополнение в банкомате"
        case "WITHDRAW":
            return "Снятие наличных"
        case "PURCHASE":
            return "Покупка товара"
        case "TRANSFER_OUT":
            return details ?? "Перевод клиенту"
        case "TRANSFER_IN":
            return details ?? "Входящий перевод"
        default:
            return details ?? type
        }
    }
    
    var iconName: String {
        switch type {
        case "DEPOSIT":
            return "arrow.down.circle.fill"
        case "WITHDRAW":
            return "banknote.fill"
        case "PURCHASE":
            return "bag.fill"
        case "TRANSFER_OUT":
            return "arrow.up.right.circle.fill"
        case "TRANSFER_IN":
            return "arrow.down.left.circle.fill"
        default:
            return "doc.text.fill"
        }
    }
    
    var formattedAmount: String {
        let sign = isPositive ? "+" : "-"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let amt = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(sign) \(amt) ₽"
    }
}

// MARK: - API Responses
struct GenericResponse: Codable {
    let success: Bool?
    let message: String?
}

struct UserAuthResponse: Codable {
    let success: Bool
    let user: User?
    let message: String?
}

struct TransferResponse: Codable {
    let success: Bool
    let new_balance: Double?
    let message: String?
}

struct PhoneLookupResponse: Codable {
    let found: Bool
    let display_name: String?
    let phone: String?
}

struct AtmActiveCodeResponse: Codable {
    let has_waiting_atm: Bool?
    let code: String?
    let remaining_seconds: Double?
}

struct BiometricsResponse: Codable {
    let success: Bool
    let is_merged: Bool?
    let user: User?
    let message: String?
}
