import SwiftUI
import WatchKit

struct TimerPresetsView: View {
    @State private var customMinutes: Int = 15
    @State private var showCustomPicker = false

    private let presets: [(label: String, minutes: Int)] = [
        ("1m", 1), ("3m", 3), ("5m", 5), ("10m", 10),
        ("15m", 15), ("20m", 20), ("30m", 30), ("60m", 60)
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        GeometryReader { geo in
            let circleSize = (geo.size.width - 6) / 2  // 2 columns with 6pt gap
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(presets, id: \.minutes) { preset in
                        NavigationLink(destination: LiveTimerView(minutes: preset.minutes)) {
                            Text(preset.label)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: circleSize, height: circleSize)
                                .background(WatchTheme.amber)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        WKInterfaceDevice.current().play(.click)
                        showCustomPicker = true
                    } label: {
                        Text("+")
                            .font(.title3)
                            .fontWeight(.light)
                            .foregroundColor(WatchTheme.textMuted)
                            .frame(width: circleSize, height: circleSize)
                            .background(WatchTheme.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Timers")
        .sheet(isPresented: $showCustomPicker) {
            NavigationStack {
                VStack(spacing: 8) {
                    Picker("Minutes", selection: $customMinutes) {
                        ForEach(1...120, id: \.self) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                    .labelsHidden()

                    NavigationLink(destination: LiveTimerView(minutes: customMinutes)) {
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(WatchTheme.amber)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        showCustomPicker = false
                    })
                }
                .navigationTitle("Custom")
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimerPresetsView()
    }
}
