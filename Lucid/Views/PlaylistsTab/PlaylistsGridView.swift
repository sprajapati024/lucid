import SwiftUI
import SwiftData

struct PlaylistsGridView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @State private var showCreateSheet = false
    @State private var playlistToDelete: Playlist?
    @State private var showDeleteAlert = false
    @State private var showDeleteError = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if playlists.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "No Playlists Yet",
                        message: "Create your first playlist to organize your music",
                        actionLabel: "Create Playlist"
                    ) {
                        showCreateSheet = true
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(playlists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    PlaylistCardView(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        playlistToDelete = playlist
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.lucidGreen)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePlaylistSheet { name in
                    let playlist = Playlist(name: name)
                    modelContext.insert(playlist)
                }
            }
            .alert("Delete Playlist?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let playlist = playlistToDelete {
                        deletePlaylist(playlist)
                    }
                }
            } message: {
                Text("This will permanently remove \"\(playlistToDelete?.name ?? "")\". Songs will stay in your library.")
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not delete the playlist. Please try again.")
            }
        }
    }

    private func deletePlaylist(_ playlist: Playlist) {
        if let currentSong = playerVM.currentSong,
           playlist.songs.contains(where: { $0.id == currentSong.id }) {
            playerVM.stop()
        }
        modelContext.delete(playlist)

        do {
            try modelContext.save()
            playlistToDelete = nil
        } catch {
            modelContext.rollback()
            showDeleteError = true
        }
    }
}
