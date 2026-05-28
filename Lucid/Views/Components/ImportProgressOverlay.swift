import SwiftUI
import Observation

@Observable
final class ImportProgressTracker {
    var total = 0
    var completed = 0

    var isDone: Bool {
        total > 0 && completed >= total
    }

    func start(total: Int) {
        self.total = total
        completed = 0
    }

    func completeOne() {
        completed = min(completed + 1, total)
    }

    func reset() {
        total = 0
        completed = 0
    }
}

struct ImportProgressOverlay: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        Double(completed) / Double(max(total, 1))
    }

    var body: some View {
        Color.lucidBlack.opacity(0.85)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Text("Importing \(completed)/\(total)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.lucidWhite)

                    ProgressView(value: progress, total: 1.0)
                        .tint(.lucidGreen)
                        .frame(width: 220)

                    Text("Please wait...")
                        .font(.system(size: 14))
                        .foregroundColor(.lucidGray)
                }
                .padding(24)
                .background(Color.lucidCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
    }
}
