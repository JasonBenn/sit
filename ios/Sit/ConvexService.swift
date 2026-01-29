import Foundation

enum ConvexError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
}

class ConvexService {
    // Production Convex deployment
    private let baseURL = "https://necessary-pony-126.convex.cloud"

    // MARK: - Query Methods

    func listBeliefs() async throws -> [Belief] {
        let response: ConvexQueryResponse<[Belief]> = try await query(function: "beliefs:listBeliefs", args: [:])
        return response.value
    }

    func listTimerPresets() async throws -> [TimerPreset] {
        let response: ConvexQueryResponse<[TimerPreset]> = try await query(function: "timerPresets:listTimerPresets", args: [:])
        return response.value
    }

    func getPromptSettings() async throws -> PromptSettings? {
        let response: ConvexQueryResponse<PromptSettings?> = try await query(function: "promptSettings:getPromptSettings", args: [:])
        return response.value
    }

    func listMeditationSessions(limit: Int? = nil) async throws -> [MeditationSession] {
        var args: [String: Any] = [:]
        if let limit = limit {
            args["limit"] = limit
        }
        let response: ConvexQueryResponse<[MeditationSession]> = try await query(function: "meditationSessions:listMeditationSessions", args: args)
        return response.value
    }

    // MARK: - Mutation Methods

    func createBelief(text: String) async throws -> String {
        let args: [String: Any] = ["text": text]
        let response: ConvexMutationResponse = try await mutate(function: "beliefs:createBelief", args: args)
        return response.value ?? ""
    }

    func logMeditationSession(durationMinutes: Double, startedAt: Double, completedAt: Double, hasInnerTimers: Bool? = nil) async throws -> String {
        var args: [String: Any] = [
            "durationMinutes": durationMinutes,
            "startedAt": startedAt,
            "completedAt": completedAt
        ]
        if let hasInnerTimers = hasInnerTimers {
            args["hasInnerTimers"] = hasInnerTimers
        }
        let response: ConvexMutationResponse = try await mutate(function: "meditationSessions:logMeditationSession", args: args)
        return response.value ?? ""
    }

    func logPromptResponse(inTheView: Bool, respondedAt: Double) async throws -> String {
        let args: [String: Any] = [
            "inTheView": inTheView,
            "respondedAt": respondedAt
        ]
        let response: ConvexMutationResponse = try await mutate(function: "promptResponses:logPromptResponse", args: args)
        return response.value ?? ""
    }

    func createTimerPreset(durationMinutes: Double, label: String?) async throws -> String {
        var args: [String: Any] = ["durationMinutes": durationMinutes]
        if let label = label, !label.isEmpty {
            args["label"] = label
        }
        let response: ConvexMutationResponse = try await mutate(function: "timerPresets:createTimerPreset", args: args)
        return response.value ?? ""
    }

    // MARK: - Generic HTTP Methods

    private func query<T: Codable>(function: String, args: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/query") else {
            throw ConvexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": function,
            "args": [args]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ConvexError.serverError("Invalid response")
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw ConvexError.decodingError(error)
        } catch {
            throw ConvexError.networkError(error)
        }
    }

    private func mutate<T: Codable>(function: String, args: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/mutation") else {
            throw ConvexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": function,
            "args": [args]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ConvexError.serverError("Invalid response")
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw ConvexError.decodingError(error)
        } catch {
            throw ConvexError.networkError(error)
        }
    }
}
