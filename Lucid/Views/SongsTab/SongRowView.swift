import SwiftUI
import SwiftData

struct SongRowView: View {
    let song: Song
    var queue: [Song]? = nil
    var showsContextMenu = true

    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.modelContext) private var modelContext

    private var isCurrentlyPlaying: Bool {
        playerVM.currentSong?.id == song.id
    }

    private var effectiveQueue: [Song] {
        queue ?? [song]
    }

    @ViewBuilder
    var body: some View {
        if showsContextMenu {
            rowButton.contextMenu {
                Button {
                    playerVM.playSong(song, queue: effectiveQueue)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }

                Button {
                    playerVM.playNext(song)
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }

                Button {
                    toggleFavorite()
                } label: {
                    Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "heart.fill" : "heart")
                }
            }
        } else {
            rowButton
        }
    }

    private var rowButton: some View {
        Button {
            playerVM.playSong(song, queue: effectiveQueue)
        } label: {
            HStack(spacing: 12) {
                AlbumArtView(data: song.albumArt, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body.weight(isCurrentlyPlaying ? .bold : .medium))
                        .foregroundColor(isCurrentlyPlaying ? .lucidGreen : .lucidWhite)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.caption)
                        .foregroundColor(.lucidGray)
                        .lineLimit(1)
                }

                Spacer()

                if song.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.lucidGreen)
                }

                Text(song.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.lucidGray)
                    .monospacedDigit()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite() {
        song.isFavorite.toggle()

        do {
            try modelContext.save()
        } catch {
            song.isFavorite.toggle()
            print("Failed to save favorite: \(error)")
        }
    }
}
