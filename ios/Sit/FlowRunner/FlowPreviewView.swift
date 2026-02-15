import SwiftUI

struct FlowPreviewView: View {
    let flow: FlowDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Preview banner
                HStack {
                    HStack(spacing: 6) {
                        Text("\u{25B6}")
                        Text("Preview Mode")
                            .font(Theme.body(12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "C8A060"))
                    Spacer()
                    Button { dismiss() } label: {
                        Text("×")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "C8A060"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "B4A078").opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "B4A078").opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 56)

                DynamicFlowView(flow: flow, isPreview: true) {
                    dismiss()
                }

                Text("Responses won't be saved")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.textMuted)
                    .padding(.bottom, 16)
            }
        }
    }
}
