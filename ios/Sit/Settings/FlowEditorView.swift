import SwiftUI

struct FlowEditorView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var steps: [FlowStep] = []
    @State private var flowDescription: String = ""
    @State private var flowName: String = ""
    @State private var visibility: String = "private"
    @State private var sourceUsername: String?
    @State private var sourceFlowName: String?
    @State private var showPreview = false
    @State private var saveTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Attribution
                    if let sourceUser = sourceUsername, let sourceName = sourceFlowName {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                            Text("Based on \(sourceUser)'s \(sourceName)")
                                .font(Theme.body(13))
                        }
                        .foregroundColor(Theme.amber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amber.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        TextField("What is this flow about?", text: $flowDescription)
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .padding(12)
                            .background(Theme.card)
                            .cornerRadius(10)
                            .onChange(of: flowDescription) { scheduleAutoSave() }
                    }

                    // Visibility
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Visibility")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        Picker("Visibility", selection: $visibility) {
                            Text("Private").tag("private")
                            Text("Public").tag("public")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: visibility) { scheduleAutoSave() }
                    }

                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            NavigationLink {
                                FlowStepEditorView(steps: $steps, stepIndex: index, onChanged: scheduleAutoSave)
                            } label: {
                                stepCard(step)
                            }
                        }

                        Button {
                            let newId = (steps.map(\.id).max() ?? 0) + 1
                            steps.append(FlowStep(
                                id: newId,
                                title: "",
                                prompt: "New step",
                                answers: [
                                    FlowAnswer(label: "Continue", destination: .submit, recordVoiceNote: false)
                                ]
                            ))
                            scheduleAutoSave()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Step")
                                    .font(Theme.body(14))
                            }
                            .foregroundColor(Theme.sage)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.sage.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }

                    // Preview button
                    Button {
                        showPreview = true
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Preview Flow")
                                .font(Theme.body(15))
                        }
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.card)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Edit Flow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView()
                        .tint(Theme.textMuted)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let flow = authManager.user?.currentFlow {
                steps = flow.stepsJson
                flowDescription = flow.description
                flowName = flow.name
                visibility = flow.visibility
                sourceUsername = flow.sourceUsername
                sourceFlowName = flow.sourceFlowName
            }
        }
        .sheet(isPresented: $showPreview) {
            if !steps.isEmpty {
                FlowPreviewView(flow: previewFlow)
            }
        }
    }

    private var previewFlow: FlowDefinition {
        FlowDefinition(
            id: "preview",
            userId: nil,
            name: flowName,
            description: flowDescription,
            stepsJson: steps,
            sourceUsername: nil,
            sourceFlowName: nil,
            visibility: visibility,
            createdAt: nil
        )
    }

    private func stepCard(_ step: FlowStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title.isEmpty ? "Step \(step.id)" : step.title)
                .font(Theme.body(15))
                .foregroundColor(Theme.text)

            Text(step.prompt)
                .font(Theme.body(13))
                .foregroundColor(Theme.textMuted)
                .lineLimit(2)

            // Routing badges
            HStack(spacing: 6) {
                ForEach(Array(step.answers.enumerated()), id: \.offset) { _, answer in
                    let destLabel: String = {
                        switch answer.destination {
                        case .step(let id):
                            let target = steps.first(where: { $0.id == id })
                            return "→ \(target?.title.isEmpty == false ? target!.title : "Step \(id)")"
                        case .submit:
                            return "→ Submit"
                        }
                    }()

                    Text(destLabel)
                        .font(Theme.body(11))
                        .foregroundColor(Theme.textDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cardAlt)
                        .cornerRadius(6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
    }

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        _ = try? await APIService.shared.updateFlow(
            name: flowName,
            description: flowDescription,
            stepsJson: steps,
            visibility: visibility
        )
        await authManager.refreshUser()
        isSaving = false
    }
}
