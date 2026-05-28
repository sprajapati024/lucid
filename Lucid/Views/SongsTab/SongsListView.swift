import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum SongsSortOrder: String, CaseIterable {
    case titleAZ
    case artist
    case dateAdded
    case duration

    var title: String {
        switch self {
        case .titleAZ: return "Title A-Z"
        case .artist: return "Artist"
        case .dateAdded: return "Date Added"
        case .duration: return "Duration"
        }
    }

    var icon: String {
        switch self {
        case .titleAZ: return "textformat"
        case .artist: return "person"
        case .dateAdded: return "calendar"
        case .duration: return "clock"
        }
    }
}

struct SongsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var showImporter = false
    @State private var songToDelete: Song?
    @State private var showDeleteAlert = false
    @State private var isImporting = false
    @State private var importTotal = 0
    @State private var importCompleted = 0
    @State private var showDeleteAlert = false
    @State private var showFavoritesOnly = false
    @State private var isImporting = false
    @State private var importCount = 0
    @State private var importProgress = 0
    @State private var importTracker = ImportProgressTracker()
    @State private var importSessionID = UUID()

    private var sortOrder: SongsSortOrder {
        SongsSortOrder(rawValue: sortOrderRawValue) ?? .titleAZ
    }

    private var displayedSongs: [Song] {
        let filtered = showFavoritesOnly ? songs.filter(\.isFavorite) : songs

        switch sortOrder {
        case .titleAZ:
            return filtered.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .artist:
            return filtered.sorted {
                let artistCompare = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if artistCompare == .orderedSame {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return artistCompare == .orderedAscending
            }
        case .dateAdded:
            return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .duration:
            return filtered.sorted { $0.duration < $1.duration }
        }
    }

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
                } else if displayedSongs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart")
                            .font(.system(size: 48))
                            .foregroundColor(.lucidGray.opacity(0.5))
                        Text("No Favorites Yet")
                            .font(.system(size: 16))
                            .foregroundColor(.lucidGray)
                    }
                } else {
                    List {
                        ForEach(displayedSongs) { song in
                            SongRowView(song: song, queue: displayedSongs, showsContextMenu: false)
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

                if isImporting {
                    ImportProgressOverlay(completed: importProgress, total: importCount)
                }
            }
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundColor(showFavoritesOnly ? .lucidGreen : .lucidGray)
                    }

                    Button {
                        shuffleAll()
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundColor(songs.isEmpty ? .lucidGray : .lucidGreen)
                    }
                    .disabled(songs.isEmpty)

                    Menu {
                        ForEach(SongsSortOrder.allCases, id: \.rawValue) { order in
                            Button {
                                sortOrderRawValue = order.rawValue
                            } label: {
                                Label(order.title, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.lucidGreen)
                    }

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
            .onChange(of: importTracker.completed) { _, completed in
                importProgress = completed
            }
            .onChange(of: importTracker.total) { _, total in
                importCount = total
            }
            .onChange(of: importTracker.isDone) { _, isDone in
                if isDone {
                    dismissImportOverlayAfterDelay()
                }
            }
        }
    }

    @ViewBuilder
    private func songContextMenu(for song: Song) -> some View {
        Button {
            playerVM.playSong(song, queue: displayedSongs)
        } label: {
            Label("Play", systemImage: "play.fill")
        }

        Button {
            playerVM.playNext(song)
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
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
            guard !urls.isEmpty else { return }

            let extractor = MetadataExtractor()
            let sessionID = UUID()
            importSessionID = sessionID
            importTracker.start(total: urls.count)
            importCount = urls.count
            importProgress = 0
            isImporting = true

            Task {
                try? await Task.sleep(for: .seconds(30))
                guard importSessionID == sessionID, isImporting else { return }
                isImporting = false
                importTracker.reset()
            }

            for url in urls {
                extractor.extractMetadata(from: url) { song in
                    if let song = song {
                        modelContext.insert(song)
                    }
                    importTracker.completeOne()
                }
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }

    private func dismissImportOverlayAfterDelay() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isImporting = false
            importTracker.reset()
        }
    }

    private func shuffleAll() {
        let shuffledSongs = songs.shuffled()
        if let firstSong = shuffledSongs.first {
            playerVM.playSong(firstSong, queue: shuffledSongs)
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
