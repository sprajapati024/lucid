import AVFoundation
import Foundation
import Observation
import SwiftData

@Observable
final class ImportInboxManager {
    static let shared = ImportInboxManager()

    var pendingFiles: [InboxItem] = []
    var failedCount = 0
    var importError: String?

    private init() {}

    struct InboxItem: Identifiable {
        let id = UUID()
        let url: URL
        var metadata: ExtractedMetadata?
        var isProcessing = false
    }

    struct ExtractedMetadata {
        var title: String
        var artist: String
        var album: String?
        var trackNumber: Int?
        var duration: TimeInterval
        var albumArt: Data?
    }

    var hasPending: Bool { !pendingFiles.isEmpty }

    func addFiles(_ urls: [URL]) {
        for url in urls {
            let item = InboxItem(url: url)
            pendingFiles.append(item)
            extractPreviewMetadata(for: item)
        }
    }

    func confirmImport(modelContext: ModelContext) {
        let items = pendingFiles.filter { !$0.isProcessing }
        for item in items {
            markProcessing(item)
            MetadataExtractor().extractMetadata(from: item.url) { [weak self] song in
                if let song {
                    modelContext.insert(song)

                    do {
                        try modelContext.save()
                    } catch {
                        self?.failedCount += 1
                        self?.importError = error.localizedDescription
                        print("Import failed: \(error)")
                    }
                } else {
                    self?.failedCount += 1
                    self?.importError = "Could not read metadata for \(item.url.lastPathComponent)."
                    print("Import failed: could not read metadata for \(item.url.lastPathComponent)")
                }
                self?.removeItem(item)
            }
        }
    }

    func removeItem(_ item: InboxItem) {
        pendingFiles.removeAll { $0.id == item.id }
    }

    func clearAll() {
        pendingFiles.removeAll()
    }

    private func markProcessing(_ item: InboxItem) {
        guard let index = pendingFiles.firstIndex(where: { $0.id == item.id }) else { return }
        pendingFiles[index].isProcessing = true
    }

    private func extractPreviewMetadata(for item: InboxItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: item.url)
            let metadata = asset.commonMetadata

            var title = item.url.deletingPathExtension().lastPathComponent
            var artist = "Unknown Artist"
            var album: String?
            var trackNumber: Int?
            var albumArt: Data?
            var duration: Double = 0

            let durationSeconds = CMTimeGetSeconds(asset.duration)
            if !durationSeconds.isNaN && durationSeconds > 0 {
                duration = durationSeconds
            }

            for metadataItem in metadata {
                guard let key = metadataItem.commonKey?.rawValue else { continue }

                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    if let value = metadataItem.stringValue, !value.isEmpty {
                        title = value
                    }
                case AVMetadataKey.commonKeyArtist.rawValue:
                    if let value = metadataItem.stringValue, !value.isEmpty {
                        artist = value
                    }
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    if let value = metadataItem.stringValue, !value.isEmpty {
                        album = value
                    }
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    albumArt = metadataItem.dataValue
                default:
                    break
                }
            }

            trackNumber = Self.extractTrackNumber(from: asset)

            let extracted = ExtractedMetadata(
                title: title,
                artist: artist,
                album: album,
                trackNumber: trackNumber,
                duration: duration,
                albumArt: albumArt
            )

            DispatchQueue.main.async {
                guard let index = self.pendingFiles.firstIndex(where: { $0.id == item.id }) else { return }
                self.pendingFiles[index].metadata = extracted
            }
        }
    }

    private static func extractTrackNumber(from asset: AVAsset) -> Int? {
        for item in asset.metadata {
            let identifier = item.identifier?.rawValue.lowercased() ?? ""
            let key = item.key.map { String(describing: $0).lowercased() } ?? ""
            guard identifier.contains("track") || key.contains("track") else { continue }

            if let number = item.numberValue?.intValue {
                return number
            }

            if let string = item.stringValue {
                let firstComponent = string.split(separator: "/").first.map(String.init) ?? string
                if let number = Int(firstComponent.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return number
                }
            }
        }

        return nil
    }
}
