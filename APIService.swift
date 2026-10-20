import Foundation
import SwiftUI
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    // Hardcoded production server URL - fixed to app.ropay.site
    static let productionBaseURL = "https://app.ropay.site"
    
    var baseURL: String {
        Self.productionBaseURL
    }
    
    private var cleanBaseURL: String {
        Self.productionBaseURL
    }
    
    // MARK: - Register Client
    func register(name: String, surname: String, phone: String, pin: String) async throws -> User {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/register") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "surname": surname,
            "phone": phone,
            "pin": pin
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(UserAuthResponse.self, from: data)
        guard res.success, let user = res.user else {
            throw NSError(domain: "APIService", code: 1, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Ошибка регистрации"])
        }
        return user
    }
    
    // MARK: - Login with PIN
    func loginWithPin(phone: String, pin: String) async throws -> User {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/login_pin") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "phone": phone,
            "pin": pin
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(UserAuthResponse.self, from: data)
        guard res.success, let user = res.user else {
            throw NSError(domain: "APIService", code: 2, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Неверный ПИН-код"])
        }
        return user
    }
    
    // MARK: - Fetch Profile
    func fetchProfile(userId: Int) async throws -> User {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/profile/\(userId)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    // MARK: - Lookup Phone
    func lookupPhone(phone: String) async throws -> PhoneLookupResponse {
        guard let encodedPhone = phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(cleanBaseURL)/api/client/lookup_phone?phone=\(encodedPhone)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PhoneLookupResponse.self, from: data)
    }
    
    // MARK: - Fetch User By Phone
    func fetchUserByPhone(phone: String) async throws -> User {
        guard let encodedPhone = phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(cleanBaseURL)/api/client/by_phone?phone=\(encodedPhone)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(User.self, from: data)
    }

    // MARK: - Transfer Funds
    func transferFunds(senderId: Int, recipientPhone: String, amount: Double) async throws -> Double {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/transfer") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "sender_id": senderId,
            "sender_user_id": senderId,
            "recipient_phone": recipientPhone,
            "amount": amount
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(TransferResponse.self, from: data)
        guard res.success, let newBal = res.new_balance else {
            throw NSError(domain: "APIService", code: 3, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Ошибка перевода"])
        }
        return newBal
    }
    
    // MARK: - Fetch Transactions
    func fetchTransactions(userId: Int) async throws -> [BankTransaction] {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/transactions/\(userId)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BankTransaction].self, from: data)
    }
    
    // MARK: - ATM Login Confirmation (Bluetooth / Code)
    func loginToAtm(userId: Int, code: String? = nil) async throws -> String {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/atm_login") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "user_id": userId
        ]
        if let code = code, !code.isEmpty {
            body["code"] = code
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(GenericResponse.self, from: data)
        guard res.success == true else {
            throw NSError(domain: "APIService", code: 4, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Банкомат отклонил вход"])
        }
        return res.message ?? "Вход в банкомат подтверждён!"
    }
    
    // MARK: - Face Login
    func loginWithFace(imageBase64: String) async throws -> User {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/face_login") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "image_base64": imageBase64
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(UserAuthResponse.self, from: data)
        guard res.success, let user = res.user else {
            throw NSError(domain: "APIService", code: 5, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Лицо не распознано"])
        }
        return user
    }
    
    // MARK: - Attach Face Biometrics
    func attachBiometrics(userId: Int, imageBase64: String) async throws -> (user: User, message: String) {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/attach_biometrics") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "image_base64": imageBase64
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(BiometricsResponse.self, from: data)
        guard res.success, let user = res.user else {
            throw NSError(domain: "APIService", code: 6, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Не удалось привязать биометрию"])
        }
        return (user: user, message: res.message ?? "Биометрия успешно подключена!")
    }
    
    // MARK: - Fetch Active ATM Code (Live polling with cache-busting)
    func fetchActiveAtmCode() async throws -> String? {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "\(cleanBaseURL)/api/atm/active_code?_t=\(ts)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2.0
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AtmActiveCodeResponse.self, from: data)
        return res.code
    }
    
    // MARK: - Batch Check Contacts
    func checkContacts(phones: [String]) async throws -> [String: ContactClientInfo] {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/check_contacts") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let body = ["phones": phones]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(CheckContactsResponse.self, from: data)
        return res.clients
    }
    
    // MARK: - Real-time WebSocket Notifications
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnectedToWebSocket: Bool = false
    private var currentListeningUserId: Int?
    
    func startTransactionNotifications(userId: Int) {
        currentListeningUserId = userId
        connectWebSocket(userId: userId)
    }
    
    func stopTransactionNotifications() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnectedToWebSocket = false
        currentListeningUserId = nil
    }
    
    private func connectWebSocket(userId: Int) {
        let wsHost = cleanBaseURL.replacingOccurrences(of: "http://", with: "ws://").replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsHost)/ws/client/\(userId)") else { return }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnectedToWebSocket = true
        
        listenWebSocketMessages(userId: userId)
    }
    
    private func listenWebSocketMessages(userId: Int) {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.listenWebSocketMessages(userId: userId)
            case .failure(_):
                self.isConnectedToWebSocket = false
                // Auto-reconnect after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if let uid = self.currentListeningUserId {
                        self.connectWebSocket(userId: uid)
                    }
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        if type == "atm_operation" {
            let title = json["title"] as? String ?? "RoPay Банкомат"
            let msg = json["message"] as? String ?? "Операция в банкомате успешно выполнена"
            let action = json["action"] as? String ?? ""
            let isDeposit = (action == "DEPOSIT" || action == "TRANSFER_IN")
            
            DispatchQueue.main.async {
                NotificationManager.shared.showAtmNotification(
                    title: title,
                    body: msg,
                    isDeposit: isDeposit
                )
            }
        }
    }
    
    // MARK: - Submit Registration Application
    func submitApplication(name: String, surname: String, phone: String, pin: String, telegram: String) async throws -> ApplicationResponse {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/application") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "surname": surname,
            "phone": phone,
            "pin": pin,
            "telegram": telegram
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(ApplicationResponse.self, from: data)
        guard res.success else {
            throw NSError(domain: "APIService", code: 1, userInfo: [NSLocalizedDescriptionKey: res.message ?? "Ошибка отправки заявки"])
        }
        return res
    }
    
    // MARK: - Fetch Statuses / Stories
    func fetchStatuses(platform: String = "ios") async throws -> [BankStatus] {
        guard let url = URL(string: "\(cleanBaseURL)/api/statuses?platform=\(platform)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(StatusesResponse.self, from: data)
        return res.statuses
    }
    
    // MARK: - Record Status View
    func recordStatusView(statusId: Int) {
        guard let url = URL(string: "\(cleanBaseURL)/api/statuses/\(statusId)/view") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req).resume()
    }
    
    // MARK: - Telemetry
    func reportTelemetry(userId: Int) {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/telemetry") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "platform": "iOS",
            "device_model": UIDevice.current.name,
            "app_version": "1.0.20"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
    
    // MARK: - Support Chat & Calls
    func initSupportChat(userId: Int, userName: String, phone: String) async throws -> (SupportChat, [SupportMessage]) {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/chat/init") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "user_name": userName,
            "phone": phone
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(SupportChatInitResponse.self, from: data)
        guard let chat = res.chat else {
            throw URLError(.cannotParseResponse)
        }
        return (chat, res.messages ?? [])
    }
    
    func fetchSupportMessages(chatId: Int) async throws -> [SupportMessage] {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/messages?chat_id=\(chatId)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(SupportMessagesResponse.self, from: data)
        return res.messages
    }
    
    func sendSupportMessage(chatId: Int, userId: Int, text: String) async throws -> (SupportMessage?, SupportMessage?, Bool) {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/send") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "chat_id": chatId,
            "user_id": userId,
            "text": text
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(SupportSendResponse.self, from: data)
        return (res.user_message, res.bot_message, res.is_operator_requested ?? false)
    }
    
    func startSupportCall(chatId: Int, userId: Int, userName: String, phone: String) async throws -> SupportCallStartResponse {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/call/start") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "chat_id": chatId,
            "user_id": userId,
            "user_name": userName,
            "phone": phone
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SupportCallStartResponse.self, from: data)
    }
    
    func sendCallSpeech(callId: Int, speechText: String) async throws -> SupportCallSpeechResponse {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/call/speech") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "call_id": callId,
            "speech_text": speechText
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SupportCallSpeechResponse.self, from: data)
    }
    
    func fetchCallStatus(callId: Int) async throws -> String {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/call/\(callId)/status") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(SupportCallStatusResponse.self, from: data)
        return res.call?.status ?? "ended"
    }
    
    func endSupportCall(callId: Int) {
        guard let url = URL(string: "\(cleanBaseURL)/api/support/call/\(callId)/end") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req).resume()
    }
    
    // MARK: - Dynamic Services (Tele2 Style)
    func fetchServices() async throws -> [BankService] {
        guard let url = URL(string: "\(cleanBaseURL)/api/services") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(ServicesResponse.self, from: data)
        return res.services
    }
}

