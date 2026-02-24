import Foundation

struct QueuedResponse: Codable, Identifiable {
    let id: UUID
    let respondedAt: Double
    let flowId: String?
    let steps: [[Int]]?
    let voiceNoteDuration: Double?
    let voiceNoteFilePath: String?  // Filename in Documents/VoiceNotes/
    let durationSeconds: Double?

    init(
        respondedAt: Double,
        flowId: String? = nil,
        steps: [[Int]]? = nil,
        voiceNoteDuration: Double? = nil,
        voiceNoteFilePath: String? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = UUID()
        self.respondedAt = respondedAt
        self.flowId = flowId
        self.steps = steps
        self.voiceNoteDuration = voiceNoteDuration
        self.voiceNoteFilePath = voiceNoteFilePath
        self.durationSeconds = durationSeconds
    }
}

@MainActor
class ResponseQueue: ObservableObject {
    static let shared = ResponseQueue()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isSyncing: Bool = false

    private let queueKey = "pendingResponses"

    init() {
        pendingCount = loadQueue().count
    }

    // MARK: - Public API

    /// Submit a response - tries API first, queues if offline
    func submit(
        flowId: String,
        steps: [[Int]],
        voiceNoteDuration: Double?,
        voiceNoteURL: URL? = nil
    ) async -> Bool {
        // Persist voice note from temp to Documents if present
        let voiceNoteFilePath: String?
        if let tempURL = voiceNoteURL {
            voiceNoteFilePath = persistVoiceNote(from: tempURL)
            if voiceNoteFilePath == nil {
                print("⚠️ Voice note failed to persist, submitting without audio")
            }
        } else {
            voiceNoteFilePath = nil
        }

        let response = QueuedResponse(
            respondedAt: Date().timeIntervalSince1970 * 1000,
            flowId: flowId,
            steps: steps,
            voiceNoteDuration: voiceNoteDuration,
            voiceNoteFilePath: voiceNoteFilePath
        )

        // Try to send immediately
        do {
            let fileURL = voiceNoteFilePath.map { getVoiceNoteURL(filename: $0) }
            try await sendToAPI(response, voiceNoteURL: fileURL)
            // Delete file after successful upload
            if let filePath = voiceNoteFilePath {
                deleteVoiceNote(filename: filePath)
            }
            print("✅ Response sent immediately")
            return true
        } catch {
            print("⚠️ API failed, queuing locally: \(error)")
            addToQueue(response)
            return false
        }
    }

    /// Submit a timer completion
    func submitTimer(durationSeconds: Double) async -> Bool {
        let response = QueuedResponse(
            respondedAt: Date().timeIntervalSince1970 * 1000,
            durationSeconds: durationSeconds
        )

        do {
            try await sendToAPI(response, voiceNoteURL: nil)
            print("✅ Timer sent immediately")
            return true
        } catch {
            print("⚠️ API failed, queuing timer locally: \(error)")
            addToQueue(response)
            return false
        }
    }

    /// Attempt to sync all queued responses
    func syncPending() async {
        guard !isSyncing else { return }

        let queue = loadQueue()
        guard !queue.isEmpty else { return }

        isSyncing = true
        print("🔄 Syncing \(queue.count) queued responses...")

        var successfulIds: [UUID] = []

        for response in queue {
            do {
                let fileURL = response.voiceNoteFilePath.map { getVoiceNoteURL(filename: $0) }
                try await sendToAPI(response, voiceNoteURL: fileURL)
                successfulIds.append(response.id)
                // Delete file after successful upload
                if let filePath = response.voiceNoteFilePath {
                    deleteVoiceNote(filename: filePath)
                }
                print("✅ Synced queued response \(response.id)")
            } catch {
                print("❌ Failed to sync \(response.id): \(error)")
                // Stop on first failure - network is probably still down
                break
            }
        }

        // Remove successful ones from queue
        if !successfulIds.isEmpty {
            removeFromQueue(ids: successfulIds)
        }

        isSyncing = false
    }

    // MARK: - Private

    private func sendToAPI(_ response: QueuedResponse, voiceNoteURL: URL? = nil) async throws {
        try await APIService.shared.logPromptResponse(
            respondedAt: response.respondedAt,
            flowId: response.flowId,
            steps: response.steps,
            voiceNoteDuration: response.voiceNoteDuration,
            voiceNoteURL: voiceNoteURL,
            durationSeconds: response.durationSeconds
        )
    }

    // MARK: - Voice Note File Management

    private var voiceNotesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VoiceNotes", isDirectory: true)
    }

    private func persistVoiceNote(from tempURL: URL) -> String? {
        do {
            try FileManager.default.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)

            let filename = "\(UUID().uuidString).m4a"
            let destURL = voiceNotesDirectory.appendingPathComponent(filename)
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            print("📁 Persisted voice note: \(filename)")
            return filename
        } catch {
            print("❌ Failed to persist voice note: \(error)")
            // Clean up temp file on failure
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }

    private func getVoiceNoteURL(filename: String) -> URL {
        voiceNotesDirectory.appendingPathComponent(filename)
    }

    private func deleteVoiceNote(filename: String) {
        let fileURL = getVoiceNoteURL(filename: filename)
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Deleted voice note: \(filename)")
    }

    private func loadQueue() -> [QueuedResponse] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([QueuedResponse].self, from: data) else {
            return []
        }
        return queue
    }

    private func saveQueue(_ queue: [QueuedResponse]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
        pendingCount = queue.count
    }

    private func addToQueue(_ response: QueuedResponse) {
        var queue = loadQueue()
        queue.append(response)
        saveQueue(queue)
        print("📥 Queued response (total: \(queue.count))")
    }

    private func removeFromQueue(ids: [UUID]) {
        var queue = loadQueue()
        queue.removeAll { ids.contains($0.id) }
        saveQueue(queue)
    }
}
