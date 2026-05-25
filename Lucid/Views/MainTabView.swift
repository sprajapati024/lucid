import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SongsListView()
                    .tabItem {
                        Label("Songs", systemImage: "music.note.list")
                    }
                    .tag(0)

                PlaylistsGridView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .tag(1)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(2)
            }
            .tint(Color.lucidGreen)

            // Mini Player sits above tab bar
            if playerVM.currentSong != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerView()
                }
            }
        }
        .sheet(isPresented: $playerVM.showNowPlaying) {
            NowPlayingView()
        }
    }
}

// MARK: - Lucid Color
extension Color {
    static let lucidGreen = Color(hex: "1DB954")
    static let lucidBlack = Color(hex: "0A0A0A")
    static let lucidDark = Color(hex: "121212")
    static let lucidCard = Color(hex: "1E1E1E")
    static let lucidGray = Color(hex: "B3B3B3")
    static let lucidWhite = Color(hex: "FAFAFA")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}