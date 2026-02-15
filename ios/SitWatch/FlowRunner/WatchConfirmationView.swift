import SwiftUI

struct WatchConfirmationView: View {
    let wasQueued: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(WatchTheme.sageText)

            Text(wasQueued ? "Saved Offline" : "Saved")
                .font(.headline)
                .foregroundColor(WatchTheme.text)

            if wasQueued {
                Text("Will sync when online")
                    .font(.caption2)
                    .foregroundColor(WatchTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.bg)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
}

#Preview {
    WatchConfirmationView(wasQueued: false)
}
