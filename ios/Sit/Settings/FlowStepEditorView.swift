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
                            .padding(16)
                            .background(Theme.cardAlt)
                            .cornerRadius(12)
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt text")
                            .font(Theme.body(13))
                            .foregroundColor(Theme.textMuted)

                        TextEditor(text: stepBinding(\.prompt))
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .scrollContentBackground(.hidden)
                            .padding(16)
                            .frame(minHeight: 100)
                            .background(Theme.cardAlt)
                            .cornerRadius(12)
                    }

                    // Answers
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Answers")
                                .font(Theme.body(13))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Button {
                                steps[stepIndex].answers.append(
                                    FlowAnswer(label: "New answer", destination: .submit, recordVoiceNote: false)
                                )
                                onChanged()
                            } label: {
                                Text("+ Add Answer")
                                    .font(Theme.body(14))
                                    .foregroundColor(Theme.sageText)
                            }
                        }

                        ForEach(Array(step.answers.enumerated()), id: \.offset) { answerIndex, _ in
                            answerEditor(answerIndex: answerIndex)
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
                            .foregroundColor(Color(hex: "C08060"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.card)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Edit Step \(stepIndex + 1)")
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
            // Header row
            HStack {
                Text("Answer \(answerIndex + 1)")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textDim)
                Spacer()
                if steps[stepIndex].answers.count > 1 {
                    Button {
                        steps[stepIndex].answers.remove(at: answerIndex)
                        onChanged()
                    } label: {
                        Text("Remove")
                            .font(Theme.body(12))
                            .foregroundColor(Color(hex: "C08060"))
                    }
                }
            }

            // Label field in sub-card
            TextField("Answer label", text: Binding(
                get: { steps[stepIndex].answers[answerIndex].label },
                set: {
                    steps[stepIndex].answers[answerIndex].label = $0
                    onChanged()
                }
            ))
            .font(Theme.body(14))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.card)
            .cornerRadius(8)

            // Destination
            HStack {
                Text("Goes to:")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textDim)
                Spacer()
                Picker("Destination", selection: destinationBinding(answerIndex: answerIndex)) {
                    ForEach(steps.filter({ $0.id != steps[stepIndex].id })) { otherStep in
                        Text(otherStep.title.isEmpty ? "Step \(otherStep.id)" : otherStep.title)
                            .tag(otherStep.id)
                    }
                    Text("Submit").tag(-1)
                }
                .tint(Theme.sageText)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(8)
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
        .padding(16)
        .background(Theme.cardAlt)
        .cornerRadius(12)
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
        VStack(spacing: 8) {
            Text(step.prompt)
                .font(Theme.display(14))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            ForEach(Array(step.answers.prefix(3).enumerated()), id: \.offset) { index, answer in
                let destIndex = destinationStepIndex(for: answer)
                if let destIndex = destIndex {
                    NavigationLink {
                        FlowStepEditorView(steps: $steps, stepIndex: destIndex, onChanged: onChanged)
                    } label: {
                        previewButton(answer: answer, index: index)
                    }
                } else {
                    previewButton(answer: answer, index: index)
                }
            }
        }
        .padding(12)
        .frame(width: 162, height: 198)
        .background(Theme.card)
        .cornerRadius(36)
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .strokeBorder(Theme.border, lineWidth: 2)
        )
        .frame(maxWidth: .infinity)
    }

    private func previewButton(answer: FlowAnswer, index: Int) -> some View {
        HStack(spacing: 4) {
            if answer.recordVoiceNote {
                Image(systemName: "mic.fill")
                    .font(.system(size: 8))
            }
            Text(answer.label)
                .font(Theme.body(11))
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(answer.recordVoiceNote
            ? Color(red: 140/255, green: 110/255, blue: 170/255)
            : (index == 0 ? Theme.sage : (index == 1 ? Theme.amber : Theme.cardAlt)))
        .cornerRadius(12)
    }

    private func destinationStepIndex(for answer: FlowAnswer) -> Int? {
        switch answer.destination {
        case .step(let id):
            return steps.firstIndex(where: { $0.id == id })
        case .submit:
            return nil
        }
    }
}
