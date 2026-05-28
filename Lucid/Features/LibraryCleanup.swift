import Foundation
import Observation
import SwiftData

struct CleanupIssue: Identifiable {
    let id = UUID()
    let type: IssueType
    let songs: [Song]
    let message: String

    enum IssueType {
        case duplicateTitle
        case missingMetadata
        case unknownArtist
        case brokenArtwork
    }
}

@Observable
final class LibraryCleanupManager {
    static let shared = LibraryCleanupManager()

    private init() {}

    func findIssues(songs: [Song]) -> [CleanupIssue] {
        var issues: [CleanupIssue] = []

        var titleArtistGroups: [String: [Song]] = [:]
        for song in songs {
            let key = "\(song.title.normalizedCleanupKey)::\(song.artist.normalizedCleanupKey)"
            titleArtistGroups[key, default: []].append(song)
        }

        for (_, group) in titleArtistGroups where group.count > 1 {
            let fileURLs = Set(group.compactMap { $0.absoluteFileURL?.absoluteString })
            if fileURLs.count > 1 {
                issues.append(CleanupIssue(
                    type: .duplicateTitle,
                    songs: group,
                    message: "'\(group[0].title)' appears \(group.count) times"
                ))
            }
        }

        let missingTitleOrArtist = songs.filter { song in
            song.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            song.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !missingTitleOrArtist.isEmpty {
            issues.append(CleanupIssue(
                type: .missingMetadata,
                songs: missingTitleOrArtist,
                message: "\(missingTitleOrArtist.count) songs with missing title or artist"
            ))
        }

        let unknownArtist = songs.filter { song in
            let artist = song.artist.normalizedCleanupKey
            return artist.isEmpty || artist == "unknown" || artist == "unknown artist"
        }
        if !unknownArtist.isEmpty {
            issues.append(CleanupIssue(
                type: .unknownArtist,
                songs: unknownArtist,
                message: "\(unknownArtist.count) songs with unknown artist"
            ))
        }

        let brokenArt = songs.filter { song in
            song.albumArt == nil || song.albumArt?.isEmpty == true
        }
        if !brokenArt.isEmpty {
            issues.append(CleanupIssue(
                type: .brokenArtwork,
                songs: brokenArt,
                message: "\(brokenArt.count) songs with missing artwork"
            ))
        }

        return issues
    }

    func mergeDuplicates(primary: Song, duplicates: [Song], modelContext: ModelContext) {
        for duplicate in duplicates where duplicate.id != primary.id {
            if let url = duplicate.absoluteFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(duplicate)
        }
    }
}

private extension String {
    var normalizedCleanupKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
