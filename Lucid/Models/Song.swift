import Foundation
import SwiftData

@Model
final class Song {
    var id: UUID
    var title: String
    var artist: String
    var albumTitle: String?
    var duration: Double // seconds
    var fileURL: String // relative path in Documents
    @Attribute(.externalStorage) var albumArt: Data?
    var dateAdded: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        albumTitle: String? = nil,
        duration: Double,
        fileURL: String,
        albumArt: Data? = nil,
        dateAdded: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.duration = duration
        self.fileURL = fileURL
        self.albumArt = albumArt
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
    }

    /// Returns the full file path within the app's Documents directory
    var absoluteFileURL: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(fileURL)
    }

    var durationFormatted: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}