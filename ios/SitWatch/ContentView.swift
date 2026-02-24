import SwiftUI

struct ContentView: View {
    @StateObject var authManager = WatchAuthManager()

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.isLoggedIn {
                NavigationStack {
                    WatchHomeView()
                }
            } else {
                WatchLoginView()
            }
        }
        .environmentObject(authManager)
    }
}

#Preview {
    ContentView()
}
