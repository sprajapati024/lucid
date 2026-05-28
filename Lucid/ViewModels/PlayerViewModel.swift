import SwiftUI
import SwiftData
import AVFoundation
import MediaPlayer

enum RepeatMode {
    case off, all, one
}

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var showNowPlaying = false
    @Published var queueCount: Int = 0
    @Published var currentQueueIndex: Int = 0
    @Published var queueItems: [Song] = []

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var queue: [Song] = []
    private var queueIndex: Int = 0
    private var originalQueue: [Song] = []
    private var lastSaveTime: Date = .distantPast
    private var isRestoringPlaybackState = false

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupNotifications()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    // MARK: - Remote Commands (Lock Screen / Control Center)

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        NotificationCenter.default.addObserver(
            forName: .sleepTimerExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Playback Controls

    func playSong(_ song: Song, queue: [Song]) {
        self.originalQueue = queue
        self.queue = isShuffled ? queue.shuffled() : queue
        if let idx = self.queue.firstIndex(where: { $0.id == song.id }) {
            self.queueIndex = idx
        }
        syncQueueDisplayState()
        loadAndPlay(song)
    }

    func playNext(_ song: Song) {
        guard let currentSong else {
            playSong(song, queue: [song])
            return
        }

        queue.removeAll { $0.id == song.id }
        if let currentIndex = queue.firstIndex(where: { $0.id == currentSong.id }) {
            queueIndex = currentIndex
        }
        let insertionIndex = min(queueIndex + 1, queue.count)
        queue.insert(song, at: insertionIndex)
        originalQueue = queue
        syncQueueDisplayState()
        postPlaybackStateNotification()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        startDisplayLink()
        postPlaybackStateNotification()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        stopDisplayLink()
        postPlaybackStateNotification()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopDisplayLink()
        clearNowPlayingInfo()
        // Clear all playback state so mini player / Now Playing hide cleanly
        currentSong = nil
        queue = []
        queueIndex = 0
        originalQueue = []
        showNowPlaying = false
        syncQueueDisplayState()
        postPlaybackStateNotification()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if repeatMode == .one {
            seek(to: 0)
            play()
            return
        }
        queueIndex = (queueIndex + 1) % queue.count
        loadAndPlay(queue[queueIndex])
    }

    func previous() {
        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        loadAndPlay(queue[queueIndex])
    }

    func seek(to time: Double) {
        player?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
        postPlaybackStateNotification(rateLimited: true)
    }

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            queue = originalQueue.shuffled()
            // Keep current song at current index
            if let current = currentSong,
               let idx = queue.firstIndex(where: { $0.id == current.id }) {
                queue.remove(at: idx)
                queue.insert(current, at: queueIndex)
            }
        } else {
            queue = originalQueue
            if let current = currentSong,
               let idx = queue.firstIndex(where: { $0.id == current.id }) {
                queueIndex = idx
            }
        }
        syncQueueDisplayState()
        postPlaybackStateNotification()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        postPlaybackStateNotification()
    }

    func toggleFavorite() {
        currentSong?.isFavorite.toggle()
    }

    func restorePlayback(currentSong: Song?, queue restoredQueue: [Song], queueIndex restoredQueueIndex: Int, state: PlaybackState) {
        guard let currentSong else { return }

        isRestoringPlaybackState = true
        var restoredQueue = restoredQueue
        if !restoredQueue.contains(where: { $0.id == currentSong.id }) {
            restoredQueue.insert(currentSong, at: min(restoredQueueIndex, restoredQueue.count))
        }

        queue = restoredQueue
        originalQueue = restoredQueue
        queueIndex = min(max(restoredQueueIndex, 0), max(restoredQueue.count - 1, 0))
        isShuffled = state.isShuffled
        repeatMode = repeatMode(from: state.repeatModeRaw)
        syncQueueDisplayState()

        loadAndPlay(currentSong)
        seek(to: state.currentTime)
        if state.isPlaying {
            play()
        } else {
            pause()
        }
        showNowPlaying = false
        isRestoringPlaybackState = false
    }

    // MARK: - Private

    private func loadAndPlay(_ song: Song) {
        stopCurrentAudioForReload()
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            queueIndex = idx
        }
        syncQueueDisplayState()

        guard let url = song.absoluteFileURL else {
            print("Could not resolve file URL for song: \(song.title)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentSong = song
            syncQueueDisplayState()
            play()
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    private func stopCurrentAudioForReload() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopDisplayLink()
        clearNowPlayingInfo()
        currentSong = nil
    }

    private func syncQueueDisplayState() {
        queueCount = queue.count
        currentQueueIndex = queueIndex
        queueItems = queue
    }

    private func repeatMode(from rawValue: String) -> RepeatMode {
        switch rawValue {
        case "all": return .all
        case "one": return .one
        default: return .off
        }
    }

    private var repeatModeSerialized: String {
        switch repeatMode {
        case .off: return "off"
        case .all: return "all"
        case .one: return "one"
        }
    }

    private func postPlaybackStateNotification(rateLimited: Bool = false) {
        guard !isRestoringPlaybackState else { return }
        if rateLimited {
            let now = Date()
            guard now.timeIntervalSince(lastSaveTime) >= 5 else { return }
            lastSaveTime = now
        } else {
            lastSaveTime = Date()
        }

        let state = PlaybackState(
            currentSongID: currentSong?.id,
            queueSongIDs: queue.map(\.id),
            queueIndex: queueIndex,
            currentTime: currentTime,
            isShuffled: isShuffled,
            repeatModeRaw: repeatModeSerialized,
            isPlaying: isPlaying
        )
        NotificationCenter.default.post(name: .playbackStateDidChange, object: state)
    }

    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlaybackTime() {
        currentTime = player?.currentTime ?? 0
        // Auto-advance when track ends
        if let player = player, !player.isPlaying && currentTime >= duration - 0.2 {
            handleTrackEnd()
        }
    }

    private func handleTrackEnd() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            play()
        case .all:
            next()
        case .off:
            if queueIndex < queue.count - 1 {
                next()
            } else {
                stop()
            }
        }
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let artData = song.albumArt,
           let image = UIImage(data: artData) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
