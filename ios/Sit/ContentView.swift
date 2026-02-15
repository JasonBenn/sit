import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                ZStack {
                    Theme.bg.ignoresSafeArea()
                    Text("Sit")
                        .font(Theme.display(48))
                        .foregroundColor(Theme.text)
                }
            } else if !authManager.isLoggedIn {
                LoginView()
            } else {
                NavigationStack {
                    HomeView()
                }
            }
        }
    }
}
