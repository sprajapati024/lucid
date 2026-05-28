import Foundation

struct PlaybackState: Codable {
    let currentSongID: UUID?
    let queueSongIDs: [UUID]
    let queueIndex: Int
    let currentTime: Double
    let isShuffled: Bool
    let repeatModeRaw: String
    let isPlaying: Bool
}

final class QueuePersistence {
    static let shared = QueuePersistence()

    private let key = "lucid.playbackState"

    private init() {}

    func save(_ state: PlaybackState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> PlaybackState? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(PlaybackState.self, from: data) else {
            return nil
        }
        return state
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

extension Notification.Name {
    static let playbackStateDidChange = Notification.Name("playbackStateDidChange")
}
