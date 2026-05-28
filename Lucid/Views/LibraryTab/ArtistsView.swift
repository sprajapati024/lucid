import SwiftUI
import SwiftData

struct ArtistGroup: Identifiable {
    let id: String
    let name: String
    let songs: [Song]

    var songCount: Int { songs.count }
    var albumCount: Int {
        Set(songs.map { song in
            let album = song.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let albumName = album, !albumName.isEmpty {
                return albumName
            }
            return "Unknown Album"
        }).count
    }
}

struct ArtistsView: View {
    @Query(sort: \Song.artist) private var songs: [Song]

    private var artists: [ArtistGroup] {
        Dictionary(grouping: songs) { song in
            let artist = song.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            return artist.isEmpty ? "Unknown Artist" : artist
        }
        .map { name, songs in
            ArtistGroup(
                id: name,
                name: name,
                songs: songs.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            if artists.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Artists",
                    message: "Imported songs with artist metadata will appear here"
                )
            } else {
                List {
                    ForEach(artists) { artist in
                        NavigationLink {
                            ArtistDetailView(artist: artist)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artist.name)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.lucidWhite)
                                Text("\(artist.songCount) \(artist.songCount == 1 ? "song" : "songs") · \(artist.albumCount) \(artist.albumCount == 1 ? "album" : "albums")")
                                    .font(.caption)
                                    .foregroundColor(.lucidGray)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.lucidBlack)
                        .listRowSeparatorTint(Color.lucidCard)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
