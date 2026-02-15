import SwiftUI
import WatchKit

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 10) {
                NavigationLink(destination: WatchDynamicFlowView()) {
                    VStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.body)
                        Text("Check In")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(WatchTheme.sageText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchTheme.sage.opacity(0.25))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: TimerPresetsView()) {
                    VStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.body)
                        Text("Timers")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(WatchTheme.amberText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchTheme.amber.opacity(0.25))
                    .cornerRadius(12)
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
