import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.lucidGray.opacity(0.6))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.lucidWhite)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.lucidGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionLabel)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lucidBlack)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.lucidGreen)
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
