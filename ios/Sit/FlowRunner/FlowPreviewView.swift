import SwiftUI

struct FlowPreviewView: View {
    let flow: FlowDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Amber preview banner
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                    Text("Preview Mode")
                        .font(Theme.body(14))
                }
                .foregroundColor(Theme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.amber.opacity(0.15))

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
