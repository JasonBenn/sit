import SwiftUI
import WatchKit

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 12) {
                NavigationLink(value: WatchDestination.checkIn) {
                    Text("Check In")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WatchTheme.sage)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

                NavigationLink(value: WatchDestination.timers) {
                    Text("Timers")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WatchTheme.amber)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        WatchHomeView()
    }
}
