import SwiftUI

struct Step1InTheViewView: View {
    var onYes: () -> Void
    var onNo: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Are you in the View?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            HStack(spacing: 12) {
                Button(action: onYes) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                        Text("Yes")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button(action: onNo) {
                    VStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                        Text("No")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            Spacer()
        }
    }
}

#Preview {
    Step1InTheViewView(onYes: {}, onNo: {})
}
