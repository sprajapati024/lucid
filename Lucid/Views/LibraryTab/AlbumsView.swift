import SwiftUI
import SwiftData

struct AlbumGroup: Identifiable {
    let id: String
    let name: String
    let artist: String
    let songs: [Song]
    let coverArtData: Data?

    var songCount: Int { songs.count }
    var totalDuration: TimeInterval { songs.reduce(0) { $0 + $1.duration } }
}

struct AlbumsView: View {
    @Query(sort: \Song.title) private var songs: [Song]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var albums: [AlbumGroup] {
        Dictionary(grouping: songs) { song in
            let album = song.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let albumName = album, !albumName.isEmpty {
                return albumName
            }
            return "Unknown Album"
        }
        .map { name, songs in
            let sortedSongs = songs.sortedForAlbum()
            let artists = Set(sortedSongs.map { $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            return AlbumGroup(
                id: name,
                name: name,
                artist: artists.count == 1 ? (artists.first ?? "Unknown Artist") : "Various Artists",
                songs: sortedSongs,
                coverArtData: sortedSongs.first(where: { $0.albumArt != nil })?.albumArt
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            if albums.isEmpty {
                EmptyStateView(
                    icon: "square.stack",
                    title: "No Albums",
                    message: "Imported songs with album metadata will appear here"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(albums) { album in
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                AlbumCardView(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct AlbumCardView: View {
    let album: AlbumGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumArtView(data: album.coverArtData, size: 150)
                .frame(maxWidth: .infinity)

            Text(album.name)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.lucidWhite)
                .lineLimit(2)

            Text(album.artist)
                .font(.caption)
                .foregroundColor(.lucidGray)
                .lineLimit(1)

            Text("\(album.songCount) \(album.songCount == 1 ? "song" : "songs")")
                .font(.caption2)
                .foregroundColor(.lucidGray)
        }
        .padding(10)
        .background(Color.lucidCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension Array where Element == Song {
    func sortedForAlbum() -> [Song] {
        sorted {
            if let lhsTrack = $0.trackNumber, let rhsTrack = $1.trackNumber, lhsTrack != rhsTrack {
                return lhsTrack < rhsTrack
            }
            if $0.trackNumber != nil, $1.trackNumber == nil {
                return true
            }
            if $0.trackNumber == nil, $1.trackNumber != nil {
                return false
            }
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
