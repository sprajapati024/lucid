import Foundation
import Observation

enum ListeningMode: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case favorites = "Favorites Radio"
    case unplayed = "Unplayed"
    case longSongs = "Long Songs"
    case offlineShuffle = "Offline Shuffle"
    case shuffleAll = "Shuffle All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recentlyAdded: return "clock"
        case .favorites: return "heart.fill"
        case .unplayed: return "circle.dashed"
        case .longSongs: return "waveform"
        case .offlineShuffle: return "shuffle"
        case .shuffleAll: return "shuffle"
        }
    }

    var description: String {
        switch self {
        case .recentlyAdded: return "Songs added in the last 30 days"
        case .favorites: return "All your favorites, shuffled"
        case .unplayed: return "Songs you haven't played yet"
        case .longSongs: return "Songs over 5 minutes"
        case .offlineShuffle: return "Your entire library, shuffled"
        case .shuffleAll: return "Random order, everything"
        }
    }
}

@Observable
final class ListeningModesManager {
    static let shared = ListeningModesManager()

    private init() {}

    func songsFor(mode: ListeningMode, allSongs: [Song]) -> [Song] {
        switch mode {
        case .recentlyAdded:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return allSongs.filter { $0.dateAdded > cutoff }.shuffled()
        case .favorites:
            return allSongs.filter(\.isFavorite).shuffled()
        case .unplayed:
            return allSongs.filter { $0.playCount == 0 }.shuffled()
        case .longSongs:
            return allSongs.filter { $0.duration > 300 }.shuffled()
        case .offlineShuffle, .shuffleAll:
            return allSongs.shuffled()
        }
    }
}
