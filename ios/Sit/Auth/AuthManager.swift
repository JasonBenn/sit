import SwiftUI

class AuthManager: ObservableObject {
    @Published var user: UserProfile?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true

    init() {
        if KeychainHelper.shared.getToken() != nil {
            Task { await loadUser() }
        } else {
            isLoading = false
        }
    }

    @MainActor
    func login(username: String, password: String) async throws {
        let response = try await APIService.shared.login(username: username, password: password)
        KeychainHelper.shared.saveToken(response.token)
        PhoneConnectivityManager.shared.sendAuthTokenToWatch(response.token)
        self.user = response.user
        self.isLoggedIn = true
    }

    @MainActor
    func signup(username: String, password: String) async throws {
        let response = try await APIService.shared.signup(username: username, password: password)
        KeychainHelper.shared.saveToken(response.token)
        PhoneConnectivityManager.shared.sendAuthTokenToWatch(response.token)
        self.user = response.user
        self.isLoggedIn = true
    }

    @MainActor
    func logout() {
        KeychainHelper.shared.deleteToken()
        self.user = nil
        self.isLoggedIn = false
    }

    @MainActor
    func loadUser() async {
        do {
            self.user = try await APIService.shared.getMe()
            self.isLoggedIn = true
            if let token = KeychainHelper.shared.getToken() {
                PhoneConnectivityManager.shared.sendAuthTokenToWatch(token)
            }
        } catch {
            KeychainHelper.shared.deleteToken()
            self.isLoggedIn = false
        }
        self.isLoading = false
    }

    @MainActor
    func refreshUser() async {
        self.user = try? await APIService.shared.getMe()
    }
}
