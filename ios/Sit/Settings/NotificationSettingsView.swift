import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var count: Int = 3
    @State private var startHour: Int = 9
    @State private var endHour: Int = 22

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                // Count
                HStack {
                    Text("Notifications per day")
                        .font(Theme.body(16))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Stepper("\(count)", value: $count, in: 0...20)
                        .foregroundColor(Theme.text)
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(12)

                // Start time
                HStack {
                    Text("Start time")
                        .font(Theme.body(16))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $startHour) {
                        ForEach(0..<24) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.sageText)
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(12)

                // End time
                HStack {
                    Text("End time")
                        .font(Theme.body(16))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $endHour) {
                        ForEach(0..<24) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.sageText)
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(12)

                Spacer()
            }
            .padding(16)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if let user = authManager.user {
                count = user.notificationCount
                startHour = user.notificationStartHour
                endHour = user.notificationEndHour
            }
        }
        .onChange(of: count) { save() }
        .onChange(of: startHour) { save() }
        .onChange(of: endHour) { save() }
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func save() {
        Task {
            try? await APIService.shared.updateNotifications(count: count, startHour: startHour, endHour: endHour)
            await authManager.refreshUser()
        }
    }
}
