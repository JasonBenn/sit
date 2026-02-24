import Foundation
import Security

// MARK: - KeychainHelper

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.jasonbenn.sit.watchkitapp"
    private let tokenAccount = "authToken"

    private init() {}

    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - APIError

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
}

// MARK: - Auth response types

struct WatchLoginResponse: Decodable {
    let token: String
}

// MARK: - APIService

class APIService {
    static let shared = APIService()

    private let baseURL = "https://sit.jasonbenn.com"

    private var authToken: String? {
        KeychainHelper.shared.getToken()
    }

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0, "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, body)
        }
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> String {
        struct LoginBody: Encodable {
            let username: String
            let password: String
        }
        let response: WatchLoginResponse = try await post(
            "/api/auth/login",
            body: LoginBody(username: username, password: password)
        )
        KeychainHelper.shared.saveToken(response.token)
        return response.token
    }

    // MARK: - Profile

    func getMe() async throws -> WatchUserProfile {
        try await get("/api/me")
    }

    // MARK: - Prompt Response

    func logPromptResponse(
        respondedAt: Double,
        flowId: String? = nil,
        steps: [[Int]]? = nil,
        voiceNoteDuration: Double?,
        voiceNoteURL: URL? = nil,
        durationSeconds: Double? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/prompt-responses") else {
            throw APIError.invalidURL
        }

        let token = authToken

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = voiceNoteURL != nil ? 30 : 5

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        func addField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        addField("responded_at", String(respondedAt))

        if let flowId {
            addField("flow_id", flowId)
        }

        if let steps {
            let stepsData = try JSONSerialization.data(withJSONObject: steps)
            addField("steps", String(data: stepsData, encoding: .utf8)!)
        }

        if let duration = voiceNoteDuration {
            addField("voice_note_duration_seconds", String(duration))
        }

        if let durationSeconds {
            addField("duration_seconds", String(durationSeconds))
        }

        if let fileURL = voiceNoteURL, let fileData = try? Data(contentsOf: fileURL) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"voice_note\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0, "Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, "Server error")
        }

        print("✅ Response logged to API")
    }
}
