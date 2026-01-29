import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SyncViewModel()
    @State private var showingAddPreset = false

    var body: some View {
        NavigationView {
            List {
                // Sync Status Section
                Section(header: Text("Sync Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    if let lastSync = viewModel.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button("Sync Now") {
                        Task {
                            await viewModel.syncAll()
                        }
                    }
                }

                // Beliefs Section
                Section(header: Text("Beliefs (\(viewModel.beliefs.count))")) {
                    if viewModel.beliefs.isEmpty {
                        Text("No beliefs synced yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.beliefs) { belief in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(belief.text)
                                Text(formatDate(belief.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Timer Presets Section
                Section(header: Text("Timer Presets (\(viewModel.timerPresets.count))")) {
                    Button {
                        showingAddPreset = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Timer Preset")
                        }
                    }

                    if viewModel.timerPresets.isEmpty {
                        Text("No timer presets yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.timerPresets) { preset in
                            HStack {
                                VStack(alignment: .leading) {
                                    if let label = preset.label, !label.isEmpty {
                                        Text(label)
                                            .font(.headline)
                                    }
                                    Text("\(Int(preset.durationMinutes)) minutes")
                                        .font(preset.label == nil ? .body : .caption)
                                        .foregroundColor(preset.label == nil ? .primary : .secondary)
                                }
                                Spacer()
                                Image(systemName: "timer")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Prompt Settings Section
                Section(header: Text("Prompt Settings")) {
                    if let settings = viewModel.promptSettings {
                        HStack {
                            Text("Prompts per day")
                            Spacer()
                            Text("\(Int(settings.promptsPerDay))")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Waking hours")
                            Spacer()
                            Text("\(Int(settings.wakingHourStart)):00 - \(Int(settings.wakingHourEnd)):00")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No prompt settings synced yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                // Test Actions Section
                Section(header: Text("Test Actions")) {
                    Button("Log Test Meditation (5 min)") {
                        Task {
                            await viewModel.logMeditationSession(durationMinutes: 5)
                        }
                    }

                    Button("Log Test Response (Yes)") {
                        Task {
                            await viewModel.logPromptResponse(inTheView: true)
                        }
                    }

                    Button("Log Test Response (No)") {
                        Task {
                            await viewModel.logPromptResponse(inTheView: false)
                        }
                    }
                }
            }
            .navigationTitle("Sit - iOS Companion")
            .refreshable {
                await viewModel.syncAll()
            }
            .sheet(isPresented: $showingAddPreset) {
                AddPresetView(viewModel: viewModel)
            }
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Preset View

struct AddPresetView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Environment(\.dismiss) var dismiss
    @State private var label = ""
    @State private var durationMinutes: Double = 10

    private let presetOptions: [Double] = [5, 7, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Label (optional)")) {
                    TextField("e.g. Short session", text: $label)
                }

                Section(header: Text("Duration")) {
                    Picker("Minutes", selection: $durationMinutes) {
                        ForEach(presetOptions, id: \.self) { minutes in
                            Text("\(Int(minutes)) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.createTimerPreset(
                                durationMinutes: durationMinutes,
                                label: label.isEmpty ? nil : label
                            )
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create Preset")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Timer Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
