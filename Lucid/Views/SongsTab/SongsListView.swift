import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SongsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var showImporter = false
    @State private var songToDelete: Song?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if songs.isEmpty {
                    EmptyStateView(
                        icon: "music.note",
                        title: "No Songs Yet",
                        message: "Import your first MP3s from the Files app",
                        actionLabel: "Import Songs"
                    ) {
                        showImporter = true
                    }
                } else {
                    List {
                        ForEach(songs) { song in
                            SongRowView(song: song)
                                .listRowBackground(Color.lucidBlack)
                                .listRowSeparatorTint(Color.lucidCard)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        songToDelete = song
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    songContextMenu(for: song)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.lucidGreen)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType.audio],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result: result)
            }
            .alert("Delete Song?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let song = songToDelete {
                        deleteSong(song)
                    }
                }
            } message: {
                Text("This will permanently remove \"\(songToDelete?.title ?? "")\" from your library.")
            }
        }
    }

    @ViewBuilder
    private func songContextMenu(for song: Song) -> some View {
        Button {
            playerVM.playSong(song, queue: songs)
        } label: {
            Label("Play", systemImage: "play.fill")
        }

        Button {
            song.isFavorite.toggle()
        } label: {
            Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "heart.fill" : "heart")
        }

        Divider()

        Menu("Add to Playlist") {
            AddToPlaylistMenu(modelContext: modelContext, song: song)
        }

        Divider()

        Button(role: .destructive) {
            songToDelete = song
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let extractor = MetadataExtractor()
            for url in urls {
                extractor.extractMetadata(from: url) { song in
                    if let song = song {
                        modelContext.insert(song)
                    }
                }
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }

    private func deleteSong(_ song: Song) {
        // Delete the file
        if let fileURL = song.absoluteFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        // Delete the SwiftData record
        modelContext.delete(song)
        // If it was playing, stop
        if playerVM.currentSong?.id == song.id {
            playerVM.stop()
        }
    }
}

// MARK: - Add to Playlist Menu
@ViewBuilder
struct AddToPlaylistMenu: View {
    let modelContext: ModelContext
    let song: Song

    @Query private var playlists: [Playlist]

    var body: some View {
        if playlists.isEmpty {
            Text("No playlists yet")
        } else {
            ForEach(playlists) { playlist in
                Button {
                    if !playlist.songs.contains(where: { $0.id == song.id }) {
                        playlist.songs.append(song)
                    }
                } label: {
                    Label(playlist.name, systemImage: "music.note.list")
                }
            }
        }
    }
}