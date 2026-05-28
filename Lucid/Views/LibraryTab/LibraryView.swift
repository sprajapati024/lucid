import SwiftUI
import SwiftData

enum LibrarySegment: String, CaseIterable, Identifiable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"

    var id: String { rawValue }
}

struct LibraryView: View {
    @State private var selectedSegment: LibrarySegment = .songs

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $selectedSegment) {
                    ForEach(LibrarySegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                Group {
                    switch selectedSegment {
                    case .songs:
                        SongsListView()
                    case .albums:
                        AlbumsView()
                    case .artists:
                        ArtistsView()
                    }
                }
            }
            .background(Color.lucidBlack.ignoresSafeArea())
            .navigationTitle(selectedSegment.rawValue)
        }
    }
}
