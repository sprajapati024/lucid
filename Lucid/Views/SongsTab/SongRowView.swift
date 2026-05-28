import SwiftUI

struct SongRowView: View {
    let song: Song
    var queue: [Song]? = nil

    @EnvironmentObject var playerVM: PlayerViewModel

    private var isCurrentlyPlaying: Bool {
        playerVM.currentSong?.id == song.id
    }

    private var effectiveQueue: [Song] {
        queue ?? [song]
    }

    var body: some View {
        Button {
            playerVM.playSong(song, queue: effectiveQueue)
        } label: {
            HStack(spacing: 12) {
                AlbumArtView(data: song.albumArt, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 16, weight: isCurrentlyPlaying ? .bold : .medium))
                        .foregroundColor(isCurrentlyPlaying ? .lucidGreen : .lucidWhite)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.lucidGray)
                        .lineLimit(1)
                }

                Spacer()

                if song.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.lucidGreen)
                }

                Text(song.durationFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(.lucidGray)
                    .monospacedDigit()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
