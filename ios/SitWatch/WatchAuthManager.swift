import SwiftUI

@MainActor
class WatchAuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentFlow: FlowDefinition?
    @Published var notificationSettings: (count: Int, startHour: Int, endHour: Int)?

    init() {
        if KeychainHelper.shared.getToken() != nil {
            Task { await validateAndLoadProfile() }
        } else {
            isLoading = false
        }
    }

    func login(username: String, password: String) async throws {
        _ = try await APIService.shared.login(username: username, password: password)
        try await loadProfile()
        isLoggedIn = true
    }

    func loadProfile() async throws {
        let profile = try await APIService.shared.getMe()
        currentFlow = profile.currentFlow
        notificationSettings = (
            count: profile.notificationCount,
            startHour: profile.notificationStartHour,
            endHour: profile.notificationEndHour
        )
    }

    private func validateAndLoadProfile() async {
        do {
            try await loadProfile()
            isLoggedIn = true
        } catch {
            print("⚠️ Token validation failed: \(error)")
            KeychainHelper.shared.deleteToken()
            isLoggedIn = false
        }
        isLoading = false
    }
}
