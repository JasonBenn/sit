import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://sit.jasonbenn.com"

    @MainActor
    private var authToken: String? {
        WatchConnectivityManager.shared.authToken
    }

    func logPromptResponse(
        respondedAt: Double,
        flowId: String,
        steps: [[Int]],
        voiceNoteDuration: Double?,
        voiceNoteURL: URL? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/prompt-responses") else {
            throw APIError.invalidURL
        }

        let token = await authToken

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
        addField("flow_id", flowId)

        let stepsData = try JSONSerialization.data(withJSONObject: steps)
        addField("steps", String(data: stepsData, encoding: .utf8)!)

        if let duration = voiceNoteDuration {
            addField("voice_note_duration_seconds", String(duration))
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
