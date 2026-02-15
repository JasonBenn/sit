import SwiftUI
import WatchKit

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: WatchDynamicFlowView()) {
                VStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                    Text("Check In")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(WatchTheme.sageText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(WatchTheme.sage.opacity(0.25))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: TimerPresetsView()) {
                VStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.title2)
                    Text("Timers")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(WatchTheme.amberText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(WatchTheme.amber.opacity(0.25))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    NavigationStack {
        WatchHomeView()
    }
}
