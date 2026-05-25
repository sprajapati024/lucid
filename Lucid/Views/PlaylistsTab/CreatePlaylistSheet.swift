import SwiftUI

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playlistName = ""
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()
                VStack(spacing: 24) {
                    TextField("Playlist name", text: $playlistName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .foregroundColor(.lucidWhite)
                        .padding()
                        .background(Color.lucidCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.lucidGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            onCreate(name)
                        }
                        dismiss()
                    }
                    .foregroundColor(.lucidGreen)
                    .fontWeight(.semibold)
                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct AddSongsToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var playlist: Playlist
    @Query(sort: \Song.title) private var allSongs: [Song]
    @State private var selectedSongIDs: Set<UUID> = []

    var availableSongs: [Song] {
        allSongs.filter { song in
            !playlist.songs.contains(where: { $0.id == song.id })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if availableSongs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.lucidGreen)
                        Text("All songs are already in this playlist")
                            .font(.system(size: 16))
                            .foregroundColor(.lucidGray)
                    }
                } else {
                    List(availableSongs, id: \.id) { song in
                        Button {
                            if selectedSongIDs.contains(song.id) {
                                selectedSongIDs.remove(song.id)
                            } else {
                                selectedSongIDs.insert(song.id)
                            }
                        } label: {
                            HStack {
                                SongRowView(song: song)
                                Spacer()
                                if selectedSongIDs.contains(song.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.lucidGreen)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.lucidGray)
                                }
                            }
                        }
                        .listRowBackground(Color.lucidBlack)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.lucidGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedSongIDs.count))") {
                        addSelectedSongs()
                        dismiss()
                    }
                    .foregroundColor(.lucidGreen)
                    .fontWeight(.semibold)
                    .disabled(selectedSongIDs.isEmpty)
                }
            }
        }
    }

    private func addSelectedSongs() {
        let songsToAdd = allSongs.filter { selectedSongIDs.contains($0.id) }
        for song in songsToAdd {
            if !playlist.songs.contains(where: { $0.id == song.id }) {
                playlist.songs.append(song)
            }
        }
    }
}