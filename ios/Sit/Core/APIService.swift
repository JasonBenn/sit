import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case unauthorized
    case serverError(Int, String)
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://sit.jasonbenn.com"

    var authToken: String? {
        KeychainHelper.shared.getToken()
    }

    // MARK: - Auth

    func signup(username: String, password: String) async throws -> AuthResponse {
        try await post("/api/auth/signup", body: ["username": username, "password": password])
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        try await post("/api/auth/login", body: ["username": username, "password": password])
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        let _: EmptyResponse = try await post("/api/auth/change-password", body: [
            "current_password": currentPassword,
            "new_password": newPassword
        ])
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await delete("/api/auth/account")
    }

    // MARK: - User

    func getMe() async throws -> UserProfile {
        try await get("/api/me")
    }

    func updateFlow(name: String, description: String, stepsJson: [FlowStep], visibility: String) async throws -> FlowDefinition {
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "steps_json": stepsJson.map { step in
                [
                    "id": step.id,
                    "title": step.title,
                    "prompt": step.prompt,
                    "answers": step.answers.map { answer in
                        [
                            "label": answer.label,
                            "destination": answer.destination == .submit ? "submit" as Any : { if case .step(let id) = answer.destination { return id as Any } else { return "submit" as Any } }(),
                            "record_voice_note": answer.recordVoiceNote
                        ] as [String: Any]
                    }
                ] as [String: Any]
            },
            "visibility": visibility
        ]
        return try await putJSON("/api/me/flow", body: body)
    }

    func updateNotifications(count: Int, startHour: Int, endHour: Int) async throws {
        let _: EmptyResponse = try await put("/api/me/notifications", body: [
            "count": count,
            "start_hour": startHour,
            "end_hour": endHour
        ])
    }

    func updateConversationStarters(_ starters: [String]) async throws {
        let _: EmptyResponse = try await put("/api/me/conversation-starters", body: ["starters": starters])
    }

    func markOnboardingSeen() async throws {
        let _: EmptyResponse = try await put("/api/me/onboarding-seen", body: [:] as [String: String])
    }

    // MARK: - Explore

    func getPublicFlows() async throws -> [PublicFlow] {
        try await get("/api/explore/flows")
    }

    func useFlow(username: String) async throws -> FlowDefinition {
        try await post("/api/explore/use/\(username)", body: [:] as [String: String])
    }

    // MARK: - Chat

    func sendChatMessage(_ message: String) async throws -> ChatMessage {
        try await post("/api/chat", body: ["message": message])
    }

    func getChatHistory() async throws -> [ChatMessage] {
        try await get("/api/chat/history")
    }

    // MARK: - Prompt Responses

    func logPromptResponse(
        respondedAt: Double,
        flowId: String,
        steps: [[Int]],
        voiceNoteDuration: Double?,
        voiceNoteData: Data? = nil,
        voiceNoteFilename: String? = nil
    ) async throws -> PromptResponseRecord {
        guard let url = URL(string: "\(baseURL)/api/prompt-responses") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = authToken {
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
        addField("flow_id", flowId)

        let stepsData = try JSONSerialization.data(withJSONObject: steps)
        addField("steps", String(data: stepsData, encoding: .utf8)!)

        if let duration = voiceNoteDuration {
            addField("voice_note_duration_seconds", String(duration))
        }

        if let fileData = voiceNoteData, let filename = voiceNoteFilename {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"voice_note\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(statusCode, "Server error")
        }

        return try JSONDecoder().decode(PromptResponseRecord.self, from: responseData)
    }

    func getPromptResponses(limit: Int? = nil) async throws -> [PromptResponseRecord] {
        var path = "/api/prompt-responses"
        if let limit { path += "?limit=\(limit)" }
        return try await get(path)
    }

    // MARK: - Private helpers

    private struct EmptyResponse: Codable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await jsonRequest("POST", path: path, body: body)
    }

    private func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try await jsonRequest("PUT", path: path, body: body)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func putJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func jsonRequest<T: Decodable>(_ method: String, path: String, body: some Encodable) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, "Server error")
        }
    }
}
