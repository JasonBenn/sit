import SwiftUI

struct FlowStepEditorView: View {
    @Binding var steps: [FlowStep]
    let stepIndex: Int
    var onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var step: FlowStep {
        get { steps[stepIndex] }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Watch preview
                    watchPreview

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        TextField("Step title", text: stepBinding(\.title))
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .padding(12)
                            .background(Theme.card)
                            .cornerRadius(10)
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        TextEditor(text: stepBinding(\.prompt))
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 100)
                            .background(Theme.card)
                            .cornerRadius(10)
                    }

                    // Answers
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Answers")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        ForEach(Array(step.answers.enumerated()), id: \.offset) { answerIndex, _ in
                            answerEditor(answerIndex: answerIndex)
                        }

                        Button {
                            steps[stepIndex].answers.append(
                                FlowAnswer(label: "New answer", destination: .submit, recordVoiceNote: false)
                            )
                            onChanged()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Answer")
                                    .font(Theme.body(14))
                            }
                            .foregroundColor(Theme.sage)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.sage.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }

                    // Delete step
                    if steps.count > 1 {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Step")
                                    .font(Theme.body(14))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(step.title.isEmpty ? "Step \(step.id)" : step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete Step?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let removedId = steps[stepIndex].id
                steps.remove(at: stepIndex)
                // Update any destinations pointing to the removed step
                for i in steps.indices {
                    for j in steps[i].answers.indices {
                        if case .step(let targetId) = steps[i].answers[j].destination, targetId == removedId {
                            steps[i].answers[j].destination = .submit
                        }
                    }
                }
                onChanged()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the step and update any references to it.")
        }
    }

    // Binding helper for step fields
    private func stepBinding<T>(_ keyPath: WritableKeyPath<FlowStep, T>) -> Binding<T> {
        Binding(
            get: { steps[stepIndex][keyPath: keyPath] },
            set: {
                steps[stepIndex][keyPath: keyPath] = $0
                onChanged()
            }
        )
    }

    private func answerEditor(answerIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Answer label", text: Binding(
                    get: { steps[stepIndex].answers[answerIndex].label },
                    set: {
                        steps[stepIndex].answers[answerIndex].label = $0
                        onChanged()
                    }
                ))
                .font(Theme.body(15))
                .foregroundColor(Theme.text)

                if steps[stepIndex].answers.count > 1 {
                    Button {
                        steps[stepIndex].answers.remove(at: answerIndex)
                        onChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textDim)
                    }
                }
            }

            // Destination picker
            HStack {
                Text("Goes to:")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textMuted)

                Picker("Destination", selection: destinationBinding(answerIndex: answerIndex)) {
                    ForEach(steps.filter({ $0.id != steps[stepIndex].id })) { otherStep in
                        Text(otherStep.title.isEmpty ? "Step \(otherStep.id)" : otherStep.title)
                            .tag(otherStep.id)
                    }
                    Text("Submit").tag(-1)
                }
                .tint(Theme.text)
            }

            // Voice note toggle
            Toggle(isOn: Binding(
                get: { steps[stepIndex].answers[answerIndex].recordVoiceNote },
                set: {
                    steps[stepIndex].answers[answerIndex].recordVoiceNote = $0
                    onChanged()
                }
            )) {
                Text("Record voice note")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textMuted)
            }
            .tint(Theme.sage)
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(10)
    }

    private func destinationBinding(answerIndex: Int) -> Binding<Int> {
        Binding(
            get: {
                switch steps[stepIndex].answers[answerIndex].destination {
                case .step(let id): return id
                case .submit: return -1
                }
            },
            set: { newValue in
                steps[stepIndex].answers[answerIndex].destination = newValue == -1 ? .submit : .step(newValue)
                onChanged()
            }
        )
    }

    private var watchPreview: some View {
        VStack(spacing: 4) {
            Text("Watch Preview")
                .font(Theme.body(11))
                .foregroundColor(Theme.textDim)

            VStack(spacing: 8) {
                Text(step.prompt)
                    .font(Theme.display(14))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                ForEach(Array(step.answers.prefix(3).enumerated()), id: \.offset) { index, answer in
                    Text(answer.label)
                        .font(Theme.body(10))
                        .foregroundColor(index == 0 ? Theme.sageText : Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(index == 0 ? Theme.sage.opacity(0.3) : Theme.cardAlt)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .frame(width: 180, height: 200)
            .background(Theme.card)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}
