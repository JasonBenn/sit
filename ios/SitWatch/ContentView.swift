import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var selection = 1 // Start on Timers tab for testing

    var body: some View {
        TabView(selection: $selection) {
            // Beliefs Tab
            BeliefsView()
                .tabItem {
                    Label("Beliefs", systemImage: "brain.head.profile")
                }
                .tag(0)

            // Timer Presets Tab
            TimerPresetsView()
                .tabItem {
                    Label("Timers", systemImage: "timer")
                }
                .tag(1)

            // Prompt Response Tab
            PromptResponseView()
                .tabItem {
                    Label("Prompts", systemImage: "questionmark.bubble")
                }
                .tag(2)

            // Test Actions Tab
            TestActionsView()
                .tabItem {
                    Label("Test", systemImage: "checkmark.circle")
                }
                .tag(3)
        }
    }
}

// MARK: - Beliefs View

struct BeliefsView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var showingAddBelief = false

    var body: some View {
        NavigationView {
            List {
                // Add Belief as NavigationLink at top
                NavigationLink(destination: AddBeliefView().environmentObject(viewModel)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("Add Belief")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                .listRowBackground(Color.green.opacity(0.2))

                // Beliefs Section
                if !viewModel.beliefs.isEmpty {
                    Section(header: Text("Your Beliefs").font(.caption2).foregroundColor(.secondary)) {
                        ForEach(viewModel.beliefs) { belief in
                            NavigationLink(destination: BeliefDetailView(belief: belief)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(belief.text)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text(formatDate(belief.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Beliefs")
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Belief View

struct AddBeliefView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @Environment(\.dismiss) var dismiss
    @State private var beliefText = ""
    @State private var showingConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("New Limiting Belief")
                    .font(.caption)
                    .fontWeight(.semibold)

                // TextField supports both typing (simulator) and dictation (device)
                TextField("Tap to type or dictate", text: $beliefText)
                    .font(.caption)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)

                    Button("Save") {
                        saveBelief()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .disabled(beliefText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .alert("Saved", isPresented: $showingConfirmation) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Belief will sync to Convex")
            }
        }
    }

    private func saveBelief() {
        let trimmedText = beliefText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        viewModel.createBelief(text: trimmedText)
        showingConfirmation = true
    }
}

// MARK: - Belief Detail View

struct BeliefDetailView: View {
    let belief: Belief

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(belief.text)
                    .font(.body)

                Text(formatDate(belief.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Belief")
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Timer Presets View

struct TimerPresetsView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @StateObject private var timerViewModel = TimerViewModel()
    @State private var selectedPreset: TimerPreset?
    @State private var showingSettings = false
    @State private var showingTimer = false

    var body: some View {
        NavigationView {
            List {
                if viewModel.timerPresets.isEmpty {
                    Text("No presets yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(viewModel.timerPresets) { preset in
                        Button {
                            selectedPreset = preset
                            showingSettings = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let label = preset.label, !label.isEmpty {
                                        Text(label)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    Text("\(Int(preset.durationMinutes)) min")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Timers")
            .sheet(isPresented: $showingSettings) {
                if let preset = selectedPreset {
                    TimerSettingsSheet(
                        timerViewModel: timerViewModel,
                        preset: preset,
                        onStart: {
                            showingTimer = true
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showingTimer) {
                if let preset = selectedPreset {
                    NavigationView {
                        TimerRunningView(
                            timerViewModel: timerViewModel,
                            preset: preset
                        )
                        .environmentObject(viewModel)
                    }
                } else {
                    // Fallback - should never happen but prevents black screen
                    Text("Error: No preset selected")
                        .onAppear { showingTimer = false }
                }
            }
        }
    }
}

// MARK: - Test Actions View

struct TestActionsView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var showingConfirmation = false
    @State private var confirmationMessage = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection")) {
                    HStack {
                        Text("iPhone")
                        Spacer()
                        Image(systemName: viewModel.isConnectedToiPhone ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(viewModel.isConnectedToiPhone ? .green : .red)
                    }
                    .font(.caption)
                }

                Section(header: Text("Test Events")) {
                    Button("Log 5min Session") {
                        viewModel.logMeditationSession(durationMinutes: 5)
                        showConfirmation(message: "Logged 5min session")
                    }
                    .font(.caption)

                    Button("Response: Yes") {
                        viewModel.logPromptResponse(inTheView: true)
                        showConfirmation(message: "Logged Yes response")
                    }
                    .font(.caption)

                    Button("Response: No") {
                        viewModel.logPromptResponse(inTheView: false)
                        showConfirmation(message: "Logged No response")
                    }
                    .font(.caption)
                }

                Section(header: Text("Data")) {
                    HStack {
                        Text("Beliefs")
                        Spacer()
                        Text("\(viewModel.beliefs.count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)

                    HStack {
                        Text("Presets")
                        Spacer()
                        Text("\(viewModel.timerPresets.count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Test")
            .alert("Sent", isPresented: $showingConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
        }
    }

    private func showConfirmation(message: String) {
        confirmationMessage = message
        showingConfirmation = true
    }
}

// MARK: - Prompt Response View

struct PromptResponseView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @State private var showingConfirmation = false
    @State private var responseValue: Bool?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                // Question text
                Text("In the View?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Yes/No buttons
                HStack(spacing: 16) {
                    Button {
                        respondYes()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                            Text("Yes")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        respondNo()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                            Text("No")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Prompt")
            .alert("Response Logged", isPresented: $showingConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                if let value = responseValue {
                    Text("Logged: \(value ? "Yes" : "No")")
                }
            }
        }
    }

    private func respondYes() {
        viewModel.logPromptResponse(inTheView: true)
        responseValue = true
        showingConfirmation = true
    }

    private func respondNo() {
        viewModel.logPromptResponse(inTheView: false)
        responseValue = false
        showingConfirmation = true
    }
}

// MARK: - Timer Settings Sheet

struct TimerSettingsSheet: View {
    @ObservedObject var timerViewModel: TimerViewModel
    let preset: TimerPreset
    @Environment(\.dismiss) var dismiss
    var onStart: () -> Void

    private let intervalOptions: [Double] = [2, 5, 10]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let label = preset.label, !label.isEmpty {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("\(Int(preset.durationMinutes)) min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Interval Bells").font(.caption2)) {
                    Toggle(isOn: $timerViewModel.intervalBellsEnabled) {
                        Text("Enable")
                            .font(.caption)
                    }

                    if timerViewModel.intervalBellsEnabled {
                        Picker("Interval", selection: $timerViewModel.intervalMinutes) {
                            ForEach(intervalOptions, id: \.self) { interval in
                                Text("\(Int(interval)) min")
                                    .font(.caption)
                                    .tag(interval)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .font(.caption)

                        Text("Subtle haptic every \(Int(timerViewModel.intervalMinutes)) minutes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        onStart()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Timer", systemImage: "play.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.caption2)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WatchViewModel())
    }
}
