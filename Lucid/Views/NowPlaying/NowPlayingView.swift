import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSeekBar = false
    @State private var seekPosition: Double = 0
    @State private var showQueue = false
    @State private var showSleepTimerSheet = false
    @State private var sleepTimerManager = SleepTimerManager.shared

    private var song: Song? { playerVM.currentSong }

    var body: some View {
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
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.lucidGray)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.lucidGray)
                    Spacer()
                    Button {
                        // Settings — future
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.lucidGray)
                    }
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
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.lucidWhite)
                        .lineLimit(1)

                    Text(song?.artist ?? "—")
                        .font(.system(size: 17))
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
                            .font(.system(size: 12))
                            .foregroundColor(.lucidGray)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(playerVM.duration))
                            .font(.system(size: 12))
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
                            .font(.system(size: 22))
                            .foregroundColor(playerVM.isShuffled ? .lucidGreen : .lucidGray)
                    }

                    Button {
                        playerVM.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.lucidWhite)
                    }

                    Button {
                        playerVM.togglePlayPause()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 68))
                            .foregroundColor(.lucidWhite)
                    }

                    Button {
                        playerVM.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.lucidWhite)
                    }

                    Button {
                        playerVM.cycleRepeatMode()
                    } label: {
                        Image(systemName: repeatIcon)
                            .font(.system(size: 22))
                            .foregroundColor(repeatIconColor)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Bottom row: heart + volume + sleep timer + queue
                HStack(spacing: 16) {
                    Button {
                        playerVM.toggleFavorite()
                    } label: {
                        Image(systemName: playerVM.currentSong?.isFavorite == true ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(playerVM.currentSong?.isFavorite == true ? .lucidGreen : .lucidGray)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.lucidGray)

                        VolumeSliderView()
                            .frame(height: 32)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.lucidGray)
                    }

                    Button {
                        showSleepTimerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sleepTimerManager.isActive ? "moon.fill" : "moon")
                                .font(.system(size: 22))
                            if sleepTimerManager.isActive {
                                Text(sleepTimerManager.remainingFormatted)
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundColor(sleepTimerManager.isActive ? .lucidGreen : .lucidGray)
                    }

                    // Queue button
                    Button {
                        showQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22))
                            .foregroundColor(.lucidGray)
                    }
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
                                        .font(.system(size: 13))
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
