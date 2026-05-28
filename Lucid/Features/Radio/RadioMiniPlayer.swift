import SwiftData
import SwiftUI

struct RadioMiniPlayer: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var radioService: RadioAudioService
    @State private var pulse = false

    private var station: RadioStation? {
        radioService.currentStation ?? playerVM.currentRadioStation
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.lucidGreen)
                .frame(height: 2)
                .opacity(pulse ? 1 : 0.45)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

            HStack(spacing: 12) {
                liveBadge

                VStack(alignment: .leading, spacing: 6) {
                    stationInfo

                    Slider(
                        value: Binding(
                            get: { Double(radioService.volume) },
                            set: { radioService.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .tint(.lucidGreen)
                    .frame(height: 18)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    playerVM.showNowPlaying = true
                }

                Spacer(minLength: 4)

                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: station?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(station?.isFavorite == true ? .lucidGreen : .lucidGray)
                        .frame(width: 36, height: 36)
                }
                .disabled(station == nil)
                .accessibilityLabel(station?.isFavorite == true ? "Remove favorite" : "Add favorite")

                Button {
                    playerVM.stopRadio()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.lucidWhite)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Stop radio")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: radioService.errorMessage == nil ? 78 : 96)
        .background(Color.lucidCard)
        .onAppear {
            pulse = true
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.lucidGreen)
                .frame(width: 7, height: 7)
                .opacity(pulse ? 1 : 0.35)

            Text(radioService.isBuffering ? "LOAD" : "LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.lucidGreen)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.lucidGreen.opacity(0.14), in: Capsule())
        .accessibilityLabel(radioService.isBuffering ? "Buffering radio" : "Live radio")
    }

    private var stationInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(station?.name ?? "Radio")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.lucidWhite)
                .lineLimit(2)

            if radioService.errorMessage != nil {
                Button {
                    retryPlayback()
                } label: {
                    Text("Tap to retry")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(stationDetail)
                    .font(.system(size: 12))
                    .foregroundColor(.lucidGray)
                    .lineLimit(1)
            }
        }
    }

    private var stationDetail: String {
        guard let station else { return "Streaming" }

        return [
            station.flagEmoji,
            station.bitrate > 0 ? "\(station.bitrate) kbps" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func toggleFavorite() {
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

    private func retryPlayback() {
        guard let retryStation = radioService.currentStation ?? station else { return }

        radioService.play(station: retryStation, modelContext: modelContext)
    }
}
