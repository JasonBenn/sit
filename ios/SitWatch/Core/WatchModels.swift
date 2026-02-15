import Foundation

// MARK: - Flow Types (mirrored from iOS)

enum AnswerDestination: Codable, Equatable {
    case step(Int)
    case submit

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .step(intValue)
        } else if let stringValue = try? container.decode(String.self), stringValue == "submit" {
            self = .submit
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected Int or \"submit\"")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .step(let id):
            try container.encode(id)
        case .submit:
            try container.encode("submit")
        }
    }
}

struct FlowAnswer: Codable, Equatable, Identifiable {
    var id: String { label }
    var label: String
    var destination: AnswerDestination
    var recordVoiceNote: Bool

    enum CodingKeys: String, CodingKey {
        case label, destination
        case recordVoiceNote = "record_voice_note"
    }
}

struct FlowStep: Codable, Equatable, Identifiable {
    var id: Int
    var title: String
    var prompt: String
    var answers: [FlowAnswer]
}

struct FlowDefinition: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let name: String
    let description: String
    let stepsJson: [FlowStep]
    let sourceUsername: String?
    let sourceFlowName: String?
    let visibility: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, visibility
        case userId = "user_id"
        case stepsJson = "steps_json"
        case sourceUsername = "source_username"
        case sourceFlowName = "source_flow_name"
        case createdAt = "created_at"
    }
}

// MARK: - Watch-specific types

struct WatchUserProfile: Codable {
    let notificationCount: Int
    let notificationStartHour: Int
    let notificationEndHour: Int
    let currentFlow: FlowDefinition?

    enum CodingKeys: String, CodingKey {
        case notificationCount = "notification_count"
        case notificationStartHour = "notification_start_hour"
        case notificationEndHour = "notification_end_hour"
        case currentFlow = "current_flow"
    }
}
