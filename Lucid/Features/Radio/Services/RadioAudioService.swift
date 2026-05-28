import AVFoundation
import Combine
import SwiftData

@MainActor
final class RadioAudioService: ObservableObject {
    static let shared = RadioAudioService()

    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var currentStation: RadioStation?
    @Published var volume: Float = 1.0
    @Published var errorMessage: String?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var playbackAttemptCount = 0
    private var activeStreamURLString: String?
    private var reconnectWorkItem: DispatchWorkItem?
    private weak var modelContext: ModelContext?

    private init() { }

    func play(station: RadioStation, modelContext: ModelContext) {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        playbackAttemptCount = 0
        activeStreamURLString = nil
        self.modelContext = modelContext
        startPlayback(station: station, updateLastPlayed: true)
    }

    func stop() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        isBuffering = false
        currentStation = nil
        activeStreamURLString = nil
    }

    func setVolume(_ volume: Float) {
        let clampedVolume = min(max(volume, 0), 1)
        self.volume = clampedVolume
        player?.volume = clampedVolume
    }

    private func startPlayback(station: RadioStation, updateLastPlayed: Bool) {
        guard let streamURLString = nextStreamURLString(for: station),
              let streamURL = URL(string: streamURLString) else {
            errorMessage = "This station does not have a valid stream URL."
            clearPlayback()
            return
        }

        try? AVAudioSession.sharedInstance().setActive(true)

        removeObservers()
        player?.pause()

        let item = AVPlayerItem(url: streamURL)
        let streamPlayer = AVPlayer(playerItem: item)
        streamPlayer.volume = volume

        playerItem = item
        player = streamPlayer
        currentStation = station
        activeStreamURLString = streamURLString
        isBuffering = true
        isPlaying = false
        errorMessage = nil

        if updateLastPlayed {
            station.lastPlayed = Date()
            try? modelContext?.save()
            trackClick(for: station)
        }

        observePlayerStatus()
        streamPlayer.play()
    }

    private func observePlayerStatus() {
        guard let playerItem, let player else { return }

        statusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }

                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.isPlaying = true
                case .failed:
                    self.isBuffering = false
                    self.isPlaying = false
                    self.handlePlaybackError(item.error ?? URLError(.cannotLoadFromNetwork))
                case .unknown:
                    self.isBuffering = true
                    self.isPlaying = false
                @unknown default:
                    self.isBuffering = false
                    self.isPlaying = false
                }
            }
        }

        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            Task { @MainActor in
                guard let self else { return }

                switch observedPlayer.timeControlStatus {
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                    self.isPlaying = false
                case .paused:
                    self.isPlaying = false
                @unknown default:
                    break
                }
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let currentItem = self.player?.currentItem,
                      currentItem.asset.isPlayable else { return }

                let duration = currentItem.duration
                if duration.isNumeric && CMTimeCompare(currentItem.currentTime(), duration) >= 0 {
                    self.stop()
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                if let error = self.playerItem?.error {
                    self.handlePlaybackError(error)
                } else {
                    self.stop()
                }
            }
        }
    }

    private func handlePlaybackError(_ error: Error) {
        guard let station = currentStation else {
            stop()
            return
        }

        playbackAttemptCount += 1

        if playbackAttemptCount >= 2 || nextStreamURLString(for: station) == nil {
            errorMessage = "Station unavailable. Try another station from \(station.country.isEmpty ? "this country" : station.country)."
            clearPlayback()
            return
        }

        errorMessage = "Stream unavailable - trying another source"
        clearPlayback()
        isBuffering = true

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.currentStation?.stationuuid == station.stationuuid else { return }
                self.startPlayback(station: station, updateLastPlayed: false)
            }
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func nextStreamURLString(for station: RadioStation) -> String? {
        let urls = [station.urlResolved, station.url]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !urls.isEmpty else { return nil }
        guard let activeStreamURLString else { return urls.first }
        guard let activeIndex = urls.firstIndex(of: activeStreamURLString) else { return urls.first }

        return urls.dropFirst(activeIndex + 1).first
    }

    private func trackClick(for station: RadioStation) {
        let stationUUID = station.stationuuid

        Task.detached(priority: .background) {
            guard let url = URL(string: "https://de1.api.radio-browser.info/json/url/\(stationUUID)") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("LucidRadio/1.0", forHTTPHeaderField: "User-Agent")
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func clearPlayback() {
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        isBuffering = false
    }

    private func removeObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil

        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
