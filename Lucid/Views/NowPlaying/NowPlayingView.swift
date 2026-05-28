import SwiftUI
import SwiftData

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @ObservedObject private var radioService = RadioAudioService.shared
    @State private var isDraggingSeekBar = false
    @State private var seekPosition: Double = 0
    @State private var showQueue = false
    @State private var showSleepTimerSheet = false
    @State private var sleepTimerManager = SleepTimerManager.shared
    @State private var livePulse = false

    private var song: Song? { playerVM.currentSong }
    private var station: RadioStation? { radioService.currentStation ?? playerVM.currentRadioStation }

    var body: some View {
        if playerVM.isRadioMode {
            radioBody
        } else {
            libraryBody
        }
    }

    private var libraryBody: some View {
        ZStack {
            // Blurred background from album art
            if let artData = song?.albumArt,
               let uiImage = UIImage(data: artData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .opacity(0.4)
            } else {
                Color.lucidBlack.ignoresSafeArea()
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, Color.lucidBlack.opacity(0.8), Color.lucidBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle + Dismiss
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.lucidGray)
                    }
                    .accessibilityLabel("Dismiss now playing")
                    Spacer()
                    Text("Now Playing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.lucidGray)
                    Spacer()
                    Button {
                        // Settings — future
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.lucidGray)
                    }
                    .accessibilityLabel("More options")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Album art
                AlbumArtView(data: song?.albumArt, size: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    .padding(.horizontal, 32)

                Spacer()

                // Song info
                VStack(spacing: 4) {
                    Text(song?.title ?? "Not Playing")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.lucidWhite)
                        .lineLimit(1)

                    Text(song?.artist ?? "—")
                        .font(.body)
                        .foregroundColor(.lucidGray)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Seek bar
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { isDraggingSeekBar ? seekPosition : playerVM.currentTime },
                            set: { newValue in
                                isDraggingSeekBar = true
                                seekPosition = newValue
                            }
                        ),
                        in: 0...max(playerVM.duration, 1)
                    ) { editing in
                        if !editing {
                            playerVM.seek(to: seekPosition)
                            isDraggingSeekBar = false
                        }
                    }
                    .tint(.lucidGreen)

                    HStack {
                        Text(formatTime(isDraggingSeekBar ? seekPosition : playerVM.currentTime))
                            .font(.caption)
                            .foregroundColor(.lucidGray)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(playerVM.duration))
                            .font(.caption)
                            .foregroundColor(.lucidGray)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        playerVM.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(playerVM.isShuffled ? .lucidGreen : .lucidGray)
                    }
                    .accessibilityLabel(playerVM.isShuffled ? "Turn shuffle off" : "Turn shuffle on")

                    Button {
                        playerVM.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.lucidWhite)
                    }
                    .accessibilityLabel("Previous track")

                    Button {
                        playerVM.togglePlayPause()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .imageScale(.large)
                            .foregroundColor(.lucidWhite)
                    }
                    .accessibilityLabel(playerVM.isPlaying ? "Pause" : "Play")

                    Button {
                        playerVM.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.lucidWhite)
                    }
                    .accessibilityLabel("Next track")

                    Button {
                        playerVM.cycleRepeatMode()
                    } label: {
                        Image(systemName: repeatIcon)
                            .font(.title3)
                            .foregroundColor(repeatIconColor)
                    }
                    .accessibilityLabel("Repeat mode")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Bottom row: heart + volume + sleep timer + queue
                HStack(spacing: 16) {
                    Button {
                        toggleLibraryFavorite()
                    } label: {
                        Image(systemName: playerVM.currentSong?.isFavorite == true ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(playerVM.currentSong?.isFavorite == true ? .lucidGreen : .lucidGray)
                    }
                    .accessibilityLabel(playerVM.currentSong?.isFavorite == true ? "Remove from favorites" : "Add to favorites")

                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundColor(.lucidGray)

                        VolumeSliderView()
                            .frame(height: 32)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundColor(.lucidGray)
                    }

                    Button {
                        showSleepTimerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sleepTimerManager.isActive ? "moon.fill" : "moon")
                                .font(.title3)
                            if sleepTimerManager.isActive {
                                Text(sleepTimerManager.remainingFormatted)
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundColor(sleepTimerManager.isActive ? .lucidGreen : .lucidGray)
                    }
                    .accessibilityLabel(sleepTimerManager.isActive ? "Sleep timer, \(sleepTimerManager.remainingFormatted) remaining" : "Sleep timer")

                    // Queue button
                    Button {
                        showQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(.lucidGray)
                    }
                    .accessibilityLabel("Queue")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheetView()
                .environmentObject(playerVM)
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet()
        }
    }

    private var radioBody: some View {
        ZStack {
            Color.lucidBlack.ignoresSafeArea()

            LinearGradient(
                colors: [Color.lucidGreen.opacity(0.18), Color.lucidBlack.opacity(0.8), Color.lucidBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.lucidGray)
                    }
                    .accessibilityLabel("Dismiss now playing")

                    Spacer()

                    Text("Radio Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.lucidGray)

                    Spacer()

                    Color.clear
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.lucidCard)
                        .frame(width: 260, height: 260)
                        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.largeTitle.weight(.medium))
                        .imageScale(.large)
                        .foregroundColor(.lucidGreen)
                        .opacity(livePulse ? 1 : 0.55)
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: livePulse)

                Spacer()

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.lucidGreen)
                            .frame(width: 8, height: 8)
                            .opacity(livePulse ? 1 : 0.35)

                        Text(radioService.isBuffering ? "BUFFERING" : "LIVE")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.lucidGreen)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.lucidGreen.opacity(0.14), in: Capsule())

                    Text(station?.name ?? "Radio")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.lucidWhite)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(radioStationDetail)
                        .font(.body)
                        .foregroundColor(.lucidGray)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 36) {
                    Button {
                        toggleRadioFavorite()
                    } label: {
                        Image(systemName: station?.isFavorite == true ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(station?.isFavorite == true ? .lucidGreen : .lucidGray)
                    }
                    .disabled(station == nil)
                    .accessibilityLabel(station?.isFavorite == true ? "Remove from favorites" : "Add to favorites")

                    if let websiteURL {
                        Button {
                            openURL(websiteURL)
                        } label: {
                            Image(systemName: "safari")
                                .font(.title)
                                .foregroundColor(.lucidGray)
                        }
                        .accessibilityLabel("Open station website")
                    }

                    Button {
                        playerVM.stopRadio()
                        dismiss()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.largeTitle)
                            .imageScale(.large)
                            .foregroundColor(.lucidWhite)
                    }
                    .accessibilityLabel("Stop radio")
                }
                .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundColor(.lucidGray)

                    Slider(
                        value: Binding(
                            get: { Double(radioService.volume) },
                            set: { radioService.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .tint(.lucidGreen)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundColor(.lucidGray)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            livePulse = true
        }
    }

    private var radioStationDetail: String {
        guard let station else { return "Streaming" }

        return [
            station.flagEmoji,
            station.country.isEmpty ? station.countryCode : station.country,
            station.bitrate > 0 ? "\(station.bitrate) kbps" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private var websiteURL: URL? {
        guard let homepage = station?.homepage.trimmingCharacters(in: .whitespacesAndNewlines),
              !homepage.isEmpty else {
            return nil
        }

        if let url = URL(string: homepage), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(homepage)")
    }

    private func toggleLibraryFavorite() {
        guard let song = playerVM.currentSong else { return }

        song.isFavorite.toggle()

        do {
            try modelContext.save()
        } catch {
            song.isFavorite.toggle()
            print("Failed to save favorite: \(error)")
        }
    }

    private func toggleRadioFavorite() {
        guard let station else { return }

        let previousIsFavorite = station.isFavorite
        let previousDateAdded = station.dateAdded

        station.isFavorite.toggle()
        station.dateAdded = station.isFavorite ? Date() : nil

        do {
            try modelContext.save()
        } catch {
            station.isFavorite = previousIsFavorite
            station.dateAdded = previousDateAdded
        }
    }

    private var repeatIcon: String {
        switch playerVM.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        playerVM.repeatMode == .off ? .lucidGray : .lucidGreen
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let secs = Int(seconds)
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}

private struct QueueSheetView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private var upcomingSongs: [Song] {
        guard playerVM.currentQueueIndex + 1 < playerVM.queueItems.count else {
            return []
        }
        return Array(playerVM.queueItems.dropFirst(playerVM.currentQueueIndex + 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if playerVM.currentSong == nil {
                    Text("No queue")
                        .foregroundColor(.lucidGray)
                } else {
                    List {
                        if let current = playerVM.currentSong {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform")
                                    .foregroundColor(.lucidGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(current.title)
                                        .foregroundColor(.lucidWhite)
                                        .lineLimit(1)
                                    Text(current.artist)
                                        .font(.caption)
                                        .foregroundColor(.lucidGray)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(Color.lucidCard)
                        }

                        ForEach(upcomingSongs) { song in
                            HStack {
                                Text(song.title)
                                    .foregroundColor(.lucidWhite)
                                    .lineLimit(1)
                                Spacer()
                                Text(song.artist)
                                    .foregroundColor(.lucidGray)
                                    .lineLimit(1)
                            }
                            .listRowBackground(Color.lucidBlack)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerVM.playSong(song, queue: playerVM.queueItems)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.lucidGreen)
                }
            }
        }
    }
}
