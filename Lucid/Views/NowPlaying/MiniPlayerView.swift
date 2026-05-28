import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.lucidGreen)
                    .frame(width: geo.size.width * playerVM.progress, height: 2)
            }
            .frame(height: 2)

            // Mini player content
            HStack(spacing: 12) {
                // Album art thumbnail
                AlbumArtView(data: playerVM.currentSong?.albumArt, size: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    playerVM.next()
                                } else if value.translation.width < -50 {
                                    playerVM.previous()
                                }
                            }
                    )

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerVM.currentSong?.title ?? "—")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.lucidWhite)
                        .lineLimit(1)

                    Text(playerVM.currentSong?.artist ?? "—")
                        .font(.caption)
                        .foregroundColor(.lucidGray)
                        .lineLimit(1)
                }

                Spacer()

                // Play/Pause
                Button {
                    playerVM.togglePlayPause()
                } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.lucidWhite)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(playerVM.isPlaying ? "Pause" : "Play")

                // Next
                Button {
                    playerVM.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundColor(.lucidWhite)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Next track")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 64)
        .background(
            Color.lucidCard
                .overlay(
                    Rectangle()
                        .fill(Color.lucidGreen)
                        .frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .top),
                    alignment: .top
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            playerVM.showNowPlaying = true
        }
    }
}
