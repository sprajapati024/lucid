import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Song.title) private var allSongs: [Song]
    @State private var searchText = ""

    private var filteredSongs: [Song] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return []
        }
        return allSongs.filter { song in
            song.title.lowercased().contains(query) ||
            song.artist.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.lucidGray)
                        TextField("Search songs, artists...", text: $searchText)
                            .foregroundColor(.lucidWhite)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.lucidCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if searchText.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.lucidGray.opacity(0.5))
                            Text("Search your library")
                                .font(.system(size: 16))
                                .foregroundColor(.lucidGray)
                            Spacer()
                        }
                    } else if filteredSongs.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.lucidGray.opacity(0.5))
                            Text("No songs match \"\(searchText)\"")
                                .font(.system(size: 16))
                                .foregroundColor(.lucidGray)
                            Spacer()
                        }
                    } else {
                        List(filteredSongs) { song in
                            SongRowView(song: song)
                                .listRowBackground(Color.lucidBlack)
                                .listRowSeparatorTint(Color.lucidCard)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding(.bottom, playerVM.currentSong != nil ? 80 : 0)
            }
            .navigationTitle("Search")
        }
    }
}