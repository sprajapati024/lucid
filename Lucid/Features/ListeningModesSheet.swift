import SwiftUI
import SwiftData

struct ListeningModesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query private var songs: [Song]

    private let manager = ListeningModesManager.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(ListeningMode.allCases) { mode in
                    Button {
                        let modeSongs = manager.songsFor(mode: mode, allSongs: songs)
                        if let first = modeSongs.first {
                            playerVM.playSong(first, queue: modeSongs)
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                                .foregroundColor(.lucidGreen)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.lucidWhite)
                                Text(mode.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.lucidGray)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.lucidGreen)
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(manager.songsFor(mode: mode, allSongs: songs).isEmpty)
                    .listRowBackground(Color.lucidCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.lucidBlack)
            .navigationTitle("Listening Modes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.lucidGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
