import SwiftUI

struct AlbumDetailView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    let album: AlbumGroup

    private var songs: [Song] {
        album.songs.sortedForAlbum()
    }

    var body: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            List {
                Section {
                    VStack(spacing: 14) {
                        AlbumArtView(data: album.coverArtData, size: 180)

                        VStack(spacing: 4) {
                            Text(album.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.lucidWhite)
                                .multilineTextAlignment(.center)

                            Text(album.artist)
                                .font(.system(size: 15))
                                .foregroundColor(.lucidGray)
                        }

                        HStack(spacing: 12) {
                            Button {
                                playAll()
                            } label: {
                                Label("Play All", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.lucidGreen)

                            Button {
                                shuffle()
                            } label: {
                                Label("Shuffle", systemImage: "shuffle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.lucidGreen)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .listRowBackground(Color.lucidBlack)

                Section {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            playerVM.playSong(song, queue: songs)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.lucidGray)
                                    .frame(width: 24, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(playerVM.currentSong?.id == song.id ? .lucidGreen : .lucidWhite)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(.lucidGray)
                                        .lineLimit(1)
                                }

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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playAll() {
        if let first = songs.first {
            playerVM.playSong(first, queue: songs)
        }
    }

    private func shuffle() {
        let shuffledSongs = songs.shuffled()
        if let first = shuffledSongs.first {
            playerVM.playSong(first, queue: shuffledSongs)
        }
    }
}
