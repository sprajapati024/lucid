import Foundation
import AVFoundation
import SwiftData

class MetadataExtractor {
    private let fileManager = FileManager.default

    /// Extracts metadata from an MP3 file and returns a fully populated Song model.
    /// Runs async on a background queue and calls the completion handler on main.
    func extractMetadata(from sourceURL: URL, completion: @escaping (Song?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: sourceURL)

            // Fetch metadata
            let metadata = asset.commonMetadata

            var title = sourceURL.deletingPathExtension().lastPathComponent
            var artist = "Unknown Artist"
            var albumTitle: String? = nil
            var albumArt: Data? = nil
            var duration: Double = 0

            // Duration
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            if !durationSeconds.isNaN && durationSeconds > 0 {
                duration = durationSeconds
            }

            // Parse metadata
            for item in metadata {
                guard let key = item.commonKey?.rawValue else { continue }

                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    if let value = item.stringValue, !value.isEmpty {
                        title = value
                    }
                case AVMetadataKey.commonKeyArtist.rawValue:
                    if let value = item.stringValue, !value.isEmpty {
                        artist = value
                    }
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    if let value = item.stringValue, !value.isEmpty {
                        albumTitle = value
                    }
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    if let data = item.dataValue {
                        albumArt = data
                    }
                default:
                    break
                }
            }

            // Copy file to app's Documents/Music directory
            let destPath = self.copyToDocuments(sourceURL)

            let song = Song(
                title: title,
                artist: artist,
                albumTitle: albumTitle,
                duration: duration,
                fileURL: destPath,
                albumArt: albumArt
            )

            DispatchQueue.main.async {
                completion(song)
            }
        }
    }

    /// Copies the source MP3 to Documents/Music/ and returns the relative path.
    private func copyToDocuments(_ sourceURL: URL) -> String {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return sourceURL.lastPathComponent
        }

        let musicDir = docs.appendingPathComponent("Music", isDirectory: true)

        // Create Music directory if needed
        if !fileManager.fileExists(atPath: musicDir.path) {
            try? fileManager.createDirectory(at: musicDir, withIntermediateDirectories: true)
        }

        let destURL = musicDir.appendingPathComponent(sourceURL.lastPathComponent)

        // If file already exists, add a unique suffix
        var finalURL = destURL
        if fileManager.fileExists(atPath: destURL.path) {
            let uuid = UUID().uuidString.prefix(8)
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            finalURL = musicDir.appendingPathComponent("\(name)_\(uuid).\(ext)")
        }

        do {
            // Start accessing security-scoped resource
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            try fileManager.copyItem(at: sourceURL, to: finalURL)
        } catch {
            print("Failed to copy MP3: \(error)")
            return sourceURL.lastPathComponent
        }

        // Return relative path from Documents
        return "Music/\(finalURL.lastPathComponent)"
    }
}