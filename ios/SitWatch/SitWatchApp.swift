import SwiftUI

@main
struct SitWatchApp: App {
    @StateObject private var viewModel = WatchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
