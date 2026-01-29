import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SyncViewModel()
    @StateObject private var watchConnectivity = WatchConnectivityService.shared

    var body: some View {
        NavigationView {
            List {
                // Connection Status Section
                Section(header: Text("Status")) {
                    HStack {
                        Text("Watch App")
                        Spacer()
                        if watchConnectivity.isWatchAppInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Installed")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Not Installed")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Watch Reachable")
                        Spacer()
                        Image(systemName: watchConnectivity.isWatchReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(watchConnectivity.isWatchReachable ? .green : .orange)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Info Section
                Section(header: Text("About")) {
                    Text("Prompt responses from your Watch are automatically logged to the server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Sit")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
