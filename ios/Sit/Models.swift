import Foundation

// MARK: - Prompt Response Model (V2 - with gate exercise flow)
struct PromptResponseV2: Codable, Identifiable {
    let id: String?
    let respondedAt: Double
    let initialAnswer: String      // "in_view" | "not_in_view"
    let gateExerciseResult: String? // "worked" | "didnt_work"
    let finalState: String         // "reflection_complete" | "voice_note_recorded"
    let voiceNoteS3Url: String?
    let voiceNoteDurationSeconds: Double?
    let transcription: String?
    let transcriptionStatus: String?
    let createdAt: Double?
}
