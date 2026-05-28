import SwiftUI

struct ArtistDetailView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    let artist: ArtistGroup

    private var albumSections: [AlbumGroup] {
        Dictionary(grouping: artist.songs) { song in
            let album = song.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            return album?.isEmpty == false ? album! : "Unknown Album"
        }
        .map { name, songs in
            let sortedSongs = songs.sortedForAlbum()
            return AlbumGroup(
                id: "\(artist.id)-\(name)",
                name: name,
                artist: artist.name,
                songs: sortedSongs,
                coverArtData: sortedSongs.first(where: { $0.albumArt != nil })?.albumArt
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.lucidWhite)
                        Text("\(artist.songCount) \(artist.songCount == 1 ? "song" : "songs") · \(artist.albumCount) \(artist.albumCount == 1 ? "album" : "albums")")
                            .font(.system(size: 14))
                            .foregroundColor(.lucidGray)
                    }
                    .padding(.vertical, 14)
                }
                .listRowBackground(Color.lucidBlack)

                ForEach(albumSections) { album in
                    Section(album.name) {
                        ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                            Button {
                                playerVM.playSong(song, queue: artist.songs)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.lucidGray)
                                        .frame(width: 24, alignment: .trailing)

                                    Text(song.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(playerVM.currentSong?.id == song.id ? .lucidGreen : .lucidWhite)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(song.durationFormatted)
                                        .font(.system(size: 12))
                                        .foregroundColor(.lucidGray)
                                        .monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.lucidBlack)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
