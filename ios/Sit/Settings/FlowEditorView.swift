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
                        HStack(spacing: 0) {
                            Text("Based on ")
                                .font(Theme.body(12))
                            + Text("'\(sourceName)'")
                                .font(Theme.body(12, weight: .medium))
                            + Text(" by \(sourceUser)")
                                .font(Theme.body(12))
                        }
                        .foregroundColor(Color(hex: "7BA085"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "5F8566").opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(hex: "5F8566").opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        TextField("Flow name", text: $flowName)
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Theme.cardAlt)
                            .cornerRadius(8)
                            .onChange(of: flowName) { scheduleAutoSave() }
                            .padding(16)
                            .background(Theme.card)
                            .cornerRadius(16)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        TextEditor(text: $flowDescription)
                            .font(Theme.body(15))
                            .foregroundColor(Theme.textMuted)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(minHeight: 60)
                            .background(Theme.cardAlt)
                            .cornerRadius(8)
                            .onChange(of: flowDescription) { scheduleAutoSave() }
                            .padding(16)
                            .background(Theme.card)
                            .cornerRadius(16)
                    }

                    // Visibility
                    HStack {
                        Text("Visibility")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.textMuted)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(["public", "private"], id: \.self) { option in
                                Button {
                                    visibility = option
                                    scheduleAutoSave()
                                } label: {
                                    Text(option.capitalized)
                                        .font(Theme.body(12, weight: visibility == option ? .medium : .regular))
                                        .foregroundColor(visibility == option ? .white : Theme.textMuted)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(visibility == option ? Theme.sage : Theme.cardAlt)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.card)
                    .cornerRadius(16)

                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("STEPS (STARTS AT STEP 1)")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

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
                            Text("+ Add Step")
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.sageText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                                )
                        }
                    }

                    // Preview button
                    Button {
                        showPreview = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("\u{25B6}")
                                .foregroundColor(Color(hex: "7BA085"))
                            Text("Preview")
                                .font(Theme.body(14, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.card)
                        .cornerRadius(16)
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
        let stepIndex = steps.firstIndex(where: { $0.id == step.id }).map({ $0 + 1 }) ?? step.id
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(stepIndex) – \(step.title)")
                    .font(Theme.body(12, weight: .medium))
                    .foregroundColor(Theme.sageText)

                Text(step.prompt)
                    .font(Theme.body(14, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)

                // Routing badges
                HStack(spacing: 6) {
                    ForEach(Array(step.answers.enumerated()), id: \.offset) { answerIndex, answer in
                        routingBadge(answer: answer, answerIndex: answerIndex)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\u{203A}")
                .font(Theme.body(20))
                .foregroundColor(Theme.textDim)
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(16)
    }

    private func routingBadge(answer: FlowAnswer, answerIndex: Int) -> some View {
        let destLabel: String = {
            switch answer.destination {
            case .step(let id):
                let target = steps.first(where: { $0.id == id })
                let targetTitle = target?.title.isEmpty == false ? target?.title ?? "Step \(id)" : "Step \(id)"
                return "\(answer.label) → \(targetTitle)"
            case .submit:
                return "\(answer.label) → Submit"
            }
        }()

        let bgColor: Color
        let textColor: Color
        if answer.recordVoiceNote {
            bgColor = Color(red: 140/255, green: 110/255, blue: 170/255).opacity(0.12)
            textColor = Color(hex: "B8A0D0")
        } else if answerIndex == 0 {
            bgColor = Color(hex: "5F8566").opacity(0.15)
            textColor = Theme.sageText
        } else {
            bgColor = Color(red: 200/255, green: 140/255, blue: 80/255).opacity(0.12)
            textColor = Color(hex: "C8A060")
        }

        return Text(destLabel)
            .font(Theme.body(11))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bgColor)
            .cornerRadius(4)
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
