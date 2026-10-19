import Foundation
import UIKit

class AdminAPIService: ObservableObject {
    static let shared = AdminAPIService()
    
    // Server endpoint
    static let defaultBaseURL = "https://app.ropay.site"
    
    @Published var baseURL: String = AdminAPIService.defaultBaseURL
    @Published var authToken: String = "ropay_admin_master_token_2026"
    
    // MARK: - Admin Login
    func login(password: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/admin/login") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "AdminAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Неверный пароль администратора"])
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            await MainActor.run {
                self.authToken = token
            }
            return true
        }
        return true
    }
    
    // MARK: - Fetch Stats
    func fetchStats() async throws -> AdminStats {
        guard let url = URL(string: "\(baseURL)/api/admin/stats") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AdminStatsResponse.self, from: data)
        return res.stats
    }
    
    // MARK: - Fetch Applications
    func fetchApplications(status: String? = nil) async throws -> [AdminApplication] {
        var urlStr = "\(baseURL)/api/admin/applications"
        if let st = status, !st.isEmpty {
            urlStr += "?status=\(st)"
        }
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AdminApplicationsResponse.self, from: data)
        return res.applications
    }
    
    // MARK: - Approve Application
    func approveApplication(id: Int, initialBalance: Double = 50000.0) async throws {
        guard let url = URL(string: "\(baseURL)/api/admin/applications/\(id)/approve") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["initial_balance": initialBalance]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Reject Application
    func rejectApplication(id: Int, reason: String = "") async throws {
        guard let url = URL(string: "\(baseURL)/api/admin/applications/\(id)/reject") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["reason": reason]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Fetch Statuses
    func fetchStatuses() async throws -> [AdminStatusItem] {
        guard let url = URL(string: "\(baseURL)/api/admin/statuses") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AdminStatusesResponse.self, from: data)
        return res.statuses
    }
    
    // MARK: - Create Status (Multipart Upload)
    func createStatus(
        mediaData: Data,
        filename: String,
        title: String,
        text: String,
        mediaType: String,
        duration: Int,
        targetPlatform: String
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/admin/statuses") else {
            throw URLError(.badURL)
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        appendFormField(name: "title", value: title)
        appendFormField(name: "text", value: text)
        appendFormField(name: "media_type", value: mediaType)
        appendFormField(name: "duration", value: "\(duration)")
        appendFormField(name: "target_platform", value: targetPlatform)
        
        // File data
        let mimeType = mediaType == "video" ? "video/mp4" : "image/jpeg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(mediaData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Delete Status
    func deleteStatus(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/admin/statuses/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Fetch Users
    func fetchUsers() async throws -> [AdminUser] {
        guard let url = URL(string: "\(baseURL)/api/admin/users") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let res = try JSONDecoder().decode(AdminUsersResponse.self, from: data)
        return res.users
    }
    
    // MARK: - Adjust User Balance
    func adjustBalance(userId: Int, delta: Double, reason: String) async throws -> Double {
        guard let url = URL(string: "\(baseURL)/api/admin/users/\(userId)/balance") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["delta": delta, "reason": reason]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let newBal = json["new_balance"] as? Double {
            return newBal
        }
        return 0.0
    }
}
