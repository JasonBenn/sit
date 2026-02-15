import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var count: Int = 3
    @State private var startHour: Int = 9
    @State private var endHour: Int = 22

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Frequency section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FREQUENCY")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        HStack {
                            Text("Check-ins per day")
                                .font(Theme.body(14))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            HStack(spacing: 16) {
                                Button { if count > 0 { count -= 1; save() } } label: {
                                    Text("\u{2212}")
                                        .font(.system(size: 18, weight: .light))
                                        .foregroundColor(Theme.textMuted)
                                        .frame(width: 36, height: 36)
                                        .background(Theme.cardAlt)
                                        .clipShape(Circle())
                                }
                                Text("\(count)")
                                    .font(Theme.body(24, weight: .medium))
                                    .foregroundColor(Theme.sageText)
                                    .frame(width: 32, alignment: .center)
                                Button { if count < 20 { count += 1; save() } } label: {
                                    Text("+")
                                        .font(.system(size: 18, weight: .light))
                                        .foregroundColor(Theme.textMuted)
                                        .frame(width: 36, height: 36)
                                        .background(Theme.cardAlt)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(20)
                        .background(Theme.card)
                        .cornerRadius(16)
                    }

                    // Schedule section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SCHEDULE")
                            .font(Theme.body(11))
                            .foregroundColor(Theme.textDim)
                            .tracking(1)
                            .padding(.leading, 4)

                        // Start time
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Day starts")
                                    .font(Theme.body(14))
                                    .foregroundColor(Theme.textMuted)
                                Text("First possible notification")
                                    .font(Theme.body(12))
                                    .foregroundColor(Theme.textDim)
                            }
                            Spacer()
                            Picker("", selection: $startHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.sageText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.cardAlt)
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .background(Theme.card)
                        .cornerRadius(16)

                        // End time
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Day ends")
                                    .font(Theme.body(14))
                                    .foregroundColor(Theme.textMuted)
                                Text("Last possible notification")
                                    .font(Theme.body(12))
                                    .foregroundColor(Theme.textDim)
                            }
                            Spacer()
                            Picker("", selection: $endHour) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.sageText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.cardAlt)
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .background(Theme.card)
                        .cornerRadius(16)
                    }

                    // Footer note
                    Text("Notifications arrive at random times within your window. Set to 0 to disable notifications.")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.textDim)
                        .padding(.horizontal, 8)

                    Spacer()
                }
                .padding(16)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if let user = authManager.user {
                count = user.notificationCount ?? 3
                startHour = user.notificationStartHour ?? 9
                endHour = user.notificationEndHour ?? 22
            }
        }
        .onChange(of: count) { save() }
        .onChange(of: startHour) { save() }
        .onChange(of: endHour) { save() }
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(ampm)"
    }

    private func save() {
        Task {
            try? await APIService.shared.updateNotifications(count: count, startHour: startHour, endHour: endHour)
            await authManager.refreshUser()
        }
    }
}
