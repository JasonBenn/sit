import Foundation

// MARK: - Belief Model
struct Belief: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: Double
    let updatedAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case createdAt
        case updatedAt
    }
}

// MARK: - Timer Preset Model
struct TimerPreset: Codable, Identifiable {
    let id: String
    let durationMinutes: Double
    let label: String?
    let order: Double
    let createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case durationMinutes
        case label
        case order
        case createdAt
    }
}

// MARK: - Prompt Settings Model
struct PromptSettings: Codable, Identifiable {
    let id: String
    let promptsPerDay: Double
    let wakingHourStart: Double
    let wakingHourEnd: Double
    let updatedAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case promptsPerDay
        case wakingHourStart
        case wakingHourEnd
        case updatedAt
    }
}

// MARK: - Meditation Session Model
struct MeditationSession: Codable, Identifiable {
    let id: String?
    let durationMinutes: Double
    let startedAt: Double
    let completedAt: Double
    let hasInnerTimers: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case durationMinutes
        case startedAt
        case completedAt
        case hasInnerTimers
    }
}

// MARK: - Prompt Response Model
struct PromptResponse: Codable, Identifiable {
    let id: String?
    let inTheView: Bool
    let respondedAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case inTheView
        case respondedAt
    }
}

// MARK: - Convex Response Wrappers
struct ConvexQueryResponse<T: Codable>: Codable {
    let status: String
    let value: T
}

struct ConvexMutationResponse: Codable {
    let status: String
    let value: String?
}
