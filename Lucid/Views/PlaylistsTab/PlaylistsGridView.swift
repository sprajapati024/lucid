import SwiftUI
import SwiftData

struct PlaylistsGridView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @State private var showCreateSheet = false
    @State private var playlistToDelete: Playlist?
    @State private var showDeleteAlert = false

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
                    List {
                        ForEach(playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                PlaylistCardView(playlist: playlist)
                            }
                            .listRowBackground(Color.lucidBlack)
                            .listRowSeparatorTint(Color.lucidCard)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    playlistToDelete = playlist
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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
        }
    }

    private func deletePlaylist(_ playlist: Playlist) {
        if let currentSong = playerVM.currentSong,
           playlist.songs.contains(where: { $0.id == currentSong.id }) {
            playerVM.stop()
        }
        modelContext.delete(playlist)
        playlistToDelete = nil
    }
}
