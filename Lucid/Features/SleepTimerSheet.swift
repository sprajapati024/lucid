import SwiftUI

struct SleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timer = SleepTimerManager.shared

    private let options = [15, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            List {
                if timer.isActive {
                    Section {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.lucidGreen)
                            Text("Timer: \(timer.remainingFormatted)")
                                .foregroundColor(.lucidWhite)
                                .monospacedDigit()
                            Spacer()
                            Button("Cancel") {
                                timer.cancel()
                                dismiss()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                Section("Set Timer") {
                    ForEach(options, id: \.self) { minutes in
                        Button {
                            timer.start(minutes: minutes)
                            dismiss()
                        } label: {
                            Text("\(minutes) minutes")
                                .foregroundColor(.lucidWhite)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.lucidBlack)
            .navigationTitle("Sleep Timer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.lucidGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
