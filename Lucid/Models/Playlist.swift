import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var songs: [Song]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        songs: [Song] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.songs = songs
    }

    var songCount: Int { songs.count }

    var totalDuration: Double {
        songs.reduce(0) { $0 + $1.duration }
    }

    var totalDurationFormatted: String {
        let totalSecs = Int(totalDuration)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(mins) min"
        }
        return "\(mins) min"
    }

    /// Cover art: use first song's album art, or nil
    var coverArt: Data? {
        songs.first?.albumArt
    }
}