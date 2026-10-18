import Foundation
import SwiftUI
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    @AppStorage("server_base_url") var baseURL: String = "http://192.168.1.247:8000"
    
    private var cleanBaseURL: String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }
        if url.hasSuffix("/") {
            url.removeLast()
        }
        return url
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
    func loginToAtm(userId: Int, code: String) async throws -> String {
        guard let url = URL(string: "\(cleanBaseURL)/api/client/atm_login") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "code": code
        ]
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
    
    // MARK: - Fetch Active ATM Code (Fallback/Auto-pairing)
    func fetchActiveAtmCode() async throws -> String? {
        guard let url = URL(string: "\(cleanBaseURL)/api/atm/active_code") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AtmActiveCodeResponse.self, from: data)
        return res.code
    }
}
