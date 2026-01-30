import SwiftUI

struct Step1InTheViewView: View {
    var onYes: () -> Void
    var onNo: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Are you in the View?")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            HStack(spacing: 20) {
                Button(action: onYes) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                        Text("Yes")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.green)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)

                Button(action: onNo) {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                        Text("No")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.orange)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

#Preview {
    Step1InTheViewView(onYes: {}, onNo: {})
}
