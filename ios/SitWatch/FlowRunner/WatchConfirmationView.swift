import SwiftUI

struct WatchConfirmationView: View {
    let wasQueued: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("\u{2713}")
                .font(.system(size: 36))
                .foregroundColor(WatchTheme.sage)

            Text(wasQueued ? "Saved Offline" : "Saved")
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(Color(hex: "C0BDB6"))

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
