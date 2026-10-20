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
    var is_business: Int?
    var business_name: String?
    
    var isBusinessAccount: Bool {
        return (is_business ?? 0) == 1
    }
    
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

// MARK: - POS Terminal Session Model (RoPay Tap / NameDrop Pay)
struct TerminalSession: Codable, Identifiable {
    let id: String
    let merchant_id: Int
    let merchant_name: String
    let amount: Double
    let description: String?
    let status: String // "waiting", "paid", "cancelled"
    let buyer_id: Int?
    let buyer_name: String?
    let created_at: String?
    let paid_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, session_id, merchant_id, merchant_name, amount, description, status, buyer_id, buyer_name, created_at, paid_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idVal = try? container.decode(String.self, forKey: .id), !idVal.isEmpty {
            self.id = idVal
        } else if let sidVal = try? container.decode(String.self, forKey: .session_id), !sidVal.isEmpty {
            self.id = sidVal
        } else {
            self.id = ""
        }
        self.merchant_id = (try? container.decode(Int.self, forKey: .merchant_id)) ?? 0
        self.merchant_name = (try? container.decode(String.self, forKey: .merchant_name)) ?? "Терминал RoPay"
        self.amount = (try? container.decode(Double.self, forKey: .amount)) ?? 0.0
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.status = (try? container.decode(String.self, forKey: .status)) ?? "waiting"
        self.buyer_id = try? container.decodeIfPresent(Int.self, forKey: .buyer_id)
        self.buyer_name = try? container.decodeIfPresent(String.self, forKey: .buyer_name)
        self.created_at = try? container.decodeIfPresent(String.self, forKey: .created_at)
        self.paid_at = try? container.decodeIfPresent(String.self, forKey: .paid_at)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(merchant_id, forKey: .merchant_id)
        try container.encode(merchant_name, forKey: .merchant_name)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(buyer_id, forKey: .buyer_id)
        try container.encodeIfPresent(buyer_name, forKey: .buyer_name)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(paid_at, forKey: .paid_at)
    }
}

struct TerminalSessionResponse: Codable {
    let success: Bool
    let message: String?
    let session: TerminalSession?
}

struct TerminalPayResponse: Codable {
    let success: Bool
    let message: String?
    let session: TerminalSession?
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

struct CheckContactsResponse: Codable {
    let status: String
    let clients: [String: ContactClientInfo]
}

struct ContactClientInfo: Codable {
    let id: Int
    let name: String
    let surname: String?
    let phone: String
    let is_client: Bool?
    
    var fullName: String {
        let sur = surname ?? ""
        return sur.isEmpty ? name : "\(name) \(sur)"
    }
}

// MARK: - Bank Status / Story Model
struct BankStatus: Codable, Identifiable, Equatable {
    let id: Int
    let title: String?
    let text: String?
    let media_url: String
    let media_type: String // "photo" or "video"
    let duration: Int? // default 10 seconds for photo
    let target_platform: String? // "all", "ios", "android"
    let views_count: Int?
    let created_at: String?
}

struct StatusesResponse: Codable {
    let success: Bool
    let statuses: [BankStatus]
}

// MARK: - Application Response
struct ApplicationResponse: Codable {
    let success: Bool
    let message: String?
    let application_id: Int?
}

// MARK: - Support Chat & Voice Call Models
struct SupportChat: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let user_name: String
    let phone: String?
    let status: String
    let unread_admin: Int?
    let unread_user: Int?
    let last_message: String?
    let created_at: String?
    let updated_at: String?
}

struct SupportMessage: Codable, Identifiable, Equatable {
    let id: Int
    let chat_id: Int
    let sender: String // "user", "bot", "operator"
    let sender_name: String?
    let text: String
    let audio_url: String?
    let created_at: String?
    
    var isUser: Bool { sender == "user" }
    var isOperator: Bool { sender == "operator" }
    var isBot: Bool { sender == "bot" }
}

struct SupportChatInitResponse: Codable {
    let success: Bool
    let chat: SupportChat?
    let messages: [SupportMessage]?
}

struct SupportMessagesResponse: Codable {
    let success: Bool
    let messages: [SupportMessage]
}

struct SupportSendResponse: Codable {
    let success: Bool
    let user_message: SupportMessage?
    let bot_message: SupportMessage?
    let is_operator_requested: Bool?
}

struct SupportCallStartResponse: Codable {
    let success: Bool
    let call_id: Int
    let status: String
    let bot_message: String?
    let audio_url: String?
}

struct SupportCallSpeechResponse: Codable {
    let success: Bool
    let status: String
    let bot_message: String?
    let audio_url: String?
    let play_hold_music: Bool?
}

struct SupportCallStatusResponse: Codable {
    let success: Bool
    let call: SupportCallInfo?
}

struct SupportCallInfo: Codable {
    let id: Int
    let chat_id: Int
    let user_id: Int
    let status: String
    let bot_message: String?
    let audio_url: String?
}

// MARK: - Dynamic Services / Mini-Apps (Tele2 Style)
struct BankService: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String?
    let icon_type: String // "symbol" or "image"
    let icon_value: String
    let target_url: String
    let is_active: Int?
    let sort_order: Int?
}

struct ServicesResponse: Codable {
    let success: Bool
    let services: [BankService]
}

// MARK: - RoPay Notifications
struct RoPayNotification: Codable, Identifiable, Equatable {
    let id: Int
    let user_id: Int
    let title: String
    let message: String
    let type: String
    let is_read: Int
    let created_at: String?
    
    var isRead: Bool {
        return is_read == 1
    }
    
    var iconName: String {
        switch type {
        case "business_approved":
            return "checkmark.seal.fill"
        case "business_rejected":
            return "xmark.seal.fill"
        case "broadcast":
            return "megaphone.fill"
        default:
            return "bell.fill"
        }
    }
}

struct NotificationsResponse: Codable {
    let success: Bool
    let notifications: [RoPayNotification]?
    let unread_count: Int?
}




