import SwiftUI
import Combine

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
    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var cancellables = Set<AnyCancellable>()

    var availableSongs: [Song] {
        allSongs.filter { song in
            !playlist.songs.contains(where: { $0.id == song.id })
        }
    }

    private var filteredSongs: [Song] {
        let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableSongs }

        let matchingSongs = availableSongs.filter { song in
            song.title.lowercased().contains(query) ||
            song.artist.lowercased().contains(query)
        }
        let selectedSongs = availableSongs.filter { selectedSongIDs.contains($0.id) }

        return (matchingSongs + selectedSongs).reduce(into: [Song]()) { result, song in
            if !result.contains(where: { $0.id == song.id }) {
                result.append(song)
            }
        }
    }

    private func setupDebounce() {
        guard cancellables.isEmpty else { return }
        $searchText
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                debouncedQuery = query
            }
            .store(in: &cancellables)
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
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.lucidGray)
                            TextField("Search songs...", text: $searchText)
                                .foregroundColor(.lucidWhite)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(Color.lucidCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        if filteredSongs.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundColor(.lucidGray.opacity(0.5))
                                Text("No results")
                                    .font(.system(size: 16))
                                    .foregroundColor(.lucidGray)
                                Spacer()
                            }
                        } else {
                            List(filteredSongs, id: \.id) { song in
                                Button {
                                    if selectedSongIDs.contains(song.id) {
                                        selectedSongIDs.remove(song.id)
                                    } else {
                                        selectedSongIDs.insert(song.id)
                                    }
                                } label: {
                                    HStack {
                                        SongRowView(song: song, showsContextMenu: false)
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
            .onAppear {
                setupDebounce()
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
