import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSongs = false

    private var playAllButton: some View {
        Button {
            if let first = playlist.songs.first {
                playerVM.playSong(first, queue: playlist.songs)
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 20))
                .foregroundColor(.lucidBlack)
                .frame(width: 44, height: 44)
                .background(Color.lucidGreen)
                .clipShape(Circle())
        }
    }

    var body: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            if playlist.songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.lucidGray)
                    Text("No songs in this playlist")
                        .font(.system(size: 16))
                        .foregroundColor(.lucidGray)
                    Button("Add Songs") {
                        showAddSongs = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lucidGreen)
                }
            } else {
                List {
                    // Header
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.lucidWhite)
                                Text("\(playlist.songCount) songs · \(playlist.totalDurationFormatted)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.lucidGray)
                            }
                            Spacer()
                            playAllButton
                        }
                        .listRowBackground(Color.lucidBlack)
                    }

                    // Songs
                    Section {
                        ForEach(playlist.songs) { song in
                            SongRowView(song: song, queue: playlist.songs)
                                .listRowBackground(Color.lucidBlack)
                                .listRowSeparatorTint(Color.lucidCard)
                        }
                        .onMove { from, to in
                            playlist.songs.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { indexSet in
                            playlist.songs.remove(atOffsets: indexSet)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    EditButton()
                        .foregroundColor(.lucidGreen)

                    Button {
                        showAddSongs = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.lucidGreen)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSongs) {
            AddSongsToPlaylistSheet(playlist: playlist)
        }
    }
}
