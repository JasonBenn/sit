import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://sit.jasonbenn.com"

    // MARK: - Prompt Responses

    func listPromptResponses(limit: Int? = nil) async throws -> [PromptResponseV2] {
        var path = "/api/prompt-responses"
        if let limit = limit {
            path += "?limit=\(limit)"
        }
        return try await get(path)
    }

    func logPromptResponse(
        respondedAt: Double,
        initialAnswer: String,
        gateExerciseResult: String?,
        finalState: String,
        voiceNoteDuration: Double?
    ) async throws -> PromptResponseV2 {
        guard let url = URL(string: "\(baseURL)/api/prompt-responses") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        func addField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        addField("responded_at", String(respondedAt))
        addField("initial_answer", initialAnswer)
        addField("final_state", finalState)

        if let gate = gateExerciseResult {
            addField("gate_exercise_result", gate)
        }

        if let duration = voiceNoteDuration {
            addField("voice_note_duration_seconds", String(duration))
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError("Invalid response")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(PromptResponseV2.self, from: responseData)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Meditation Sessions

    func logMeditationSession(
        durationMinutes: Int,
        startedAt: Double,
        completedAt: Double,
        hasInnerTimers: Bool
    ) async throws -> MeditationSession {
        let body: [String: Any] = [
            "duration_minutes": durationMinutes,
            "started_at": startedAt,
            "completed_at": completedAt,
            "has_inner_timers": hasInnerTimers
        ]
        return try await post("/api/meditation-sessions", body: body)
    }

    // MARK: - Generic HTTP Methods

    private func post<T: Codable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError("Invalid response")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func get<T: Codable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError("Invalid response")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
