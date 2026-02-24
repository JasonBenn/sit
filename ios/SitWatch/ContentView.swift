import SwiftUI

enum WatchDestination: Hashable {
    case checkIn
    case timers
}

struct ContentView: View {
    @StateObject var authManager = WatchAuthManager()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.isLoggedIn {
                NavigationStack(path: $navigationPath) {
                    WatchHomeView()
                        .navigationDestination(for: WatchDestination.self) { dest in
                            switch dest {
                            case .checkIn:
                                WatchDynamicFlowView()
                            case .timers:
                                TimerPresetsView()
                            }
                        }
                        .onAppear {
                            if AppDelegate.pendingCheckIn {
                                AppDelegate.pendingCheckIn = false
                                navigationPath.append(WatchDestination.checkIn)
                            }
                        }
                }
            } else {
                WatchLoginView()
            }
        }
        .environmentObject(authManager)
        .onReceive(NotificationCenter.default.publisher(for: .startCheckIn)) { _ in
            navigationPath = NavigationPath()
            DispatchQueue.main.async {
                navigationPath.append(WatchDestination.checkIn)
            }
        }
    }
}

#Preview {
    ContentView()
}
