import SwiftUI

struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover art
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lucidCard)

                if let artData = playlist.coverArt,
                   let uiImage = UIImage(data: artData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.lucidGray)
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.lucidWhite)
                    .lineLimit(1)

                Text("\(playlist.songCount) songs")
                    .font(.system(size: 12))
                    .foregroundColor(.lucidGray)
            }
            .padding(.horizontal, 4)
        }
    }
}