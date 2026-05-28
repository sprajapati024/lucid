import SwiftUI

struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.lucidCard, Color.lucidDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let artData = playlist.coverArt,
                   let uiImage = UIImage(data: artData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundColor(.lucidGray)
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.lucidWhite)
                    .lineLimit(1)

                Text("\(playlist.songCount) songs")
                    .font(.caption)
                    .foregroundColor(.lucidGray)
            }
        }
        .padding(10)
        .background(Color.lucidCard, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
    }
}
