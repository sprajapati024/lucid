import SwiftUI
import SwiftData

struct PlaylistsGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @State private var showCreateSheet = false

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
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80) // space for mini player
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
        }
    }
}