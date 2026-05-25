import SwiftUI

struct AlbumArtView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size > 60 ? 12 : 6)
                .fill(Color.lucidCard)

            if let artData = data,
               let uiImage = UIImage(data: artData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size > 60 ? 12 : 6))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.lucidGray)
            }
        }
        .frame(width: size, height: size)
    }
}