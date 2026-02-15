import Foundation

// MARK: - Flow Types

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

// MARK: - User Types

struct UserProfile: Codable {
    let id: String
    let username: String
    var currentFlowId: String?
    var notificationCount: Int
    var notificationStartHour: Int
    var notificationEndHour: Int
    var conversationStarters: [String]?
    var hasSeenOnboarding: Bool
    var currentFlow: FlowDefinition?

    enum CodingKeys: String, CodingKey {
        case id, username
        case currentFlowId = "current_flow_id"
        case notificationCount = "notification_count"
        case notificationStartHour = "notification_start_hour"
        case notificationEndHour = "notification_end_hour"
        case conversationStarters = "conversation_starters"
        case hasSeenOnboarding = "has_seen_onboarding"
        case currentFlow = "current_flow"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: UserProfile
}

// MARK: - Chat Types

struct ChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case createdAt = "created_at"
    }
}

// MARK: - Explore Types

struct PublicFlow: Codable, Identifiable {
    var id: String { "\(username)-\(flowName)" }
    let username: String
    let flowName: String
    let description: String
    let stepCount: Int
    let stepsJson: [FlowStep]

    enum CodingKeys: String, CodingKey {
        case username, description
        case flowName = "flow_name"
        case stepCount = "step_count"
        case stepsJson = "steps_json"
    }
}

extension PublicFlow {
    func toFlowDefinition() -> FlowDefinition {
        FlowDefinition(
            id: UUID().uuidString,
            userId: nil,
            name: flowName,
            description: description,
            stepsJson: stepsJson,
            sourceUsername: username,
            sourceFlowName: flowName,
            visibility: "public",
            createdAt: nil
        )
    }
}

// MARK: - Prompt Response

struct PromptResponseRecord: Codable, Identifiable {
    let id: String
    let respondedAt: String
    let flowId: String?
    let steps: [[Int]]?
    let voiceNoteS3Url: String?
    let voiceNoteDurationSeconds: Double?
    let transcription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case respondedAt = "responded_at"
        case flowId = "flow_id"
        case steps
        case voiceNoteS3Url = "voice_note_s3_url"
        case voiceNoteDurationSeconds = "voice_note_duration_seconds"
        case transcription
    }
}
