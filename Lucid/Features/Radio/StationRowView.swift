import SwiftData
import SwiftUI

struct StationRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var station: RadioStation

    let isHighlighted: Bool
    let onSelect: () -> Void

    init(
        station: RadioStation,
        isHighlighted: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.station = station
        self.isHighlighted = isHighlighted
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isOffline ? .secondary : .lucidWhite)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(details.isEmpty ? "Station details unavailable" : details)
                        .lineLimit(1)

                    if isOffline {
                        Text("Offline")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.lucidRed)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                toggleFavorite()
            } label: {
                Image(systemName: station.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(station.isFavorite ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(station.isFavorite ? "Remove favorite" : "Add favorite")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .padding(.vertical, 6)
        .opacity(isOffline ? 0.5 : 1.0)
        .listRowBackground(rowBackground)
    }

    private var rowBackground: Color {
        isHighlighted ? Color.lucidGreen.opacity(0.18) : Color.clear
    }

    private var details: String {
        [
            station.topTag,
            station.codec.isEmpty ? nil : station.codec,
            station.bitrate > 0 ? "\(station.bitrate) kbps" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var isOffline: Bool {
        station.isOffline
    }

    private func toggleFavorite() {
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
}

extension RadioStation {
    var isOffline: Bool {
        !lastCheckOk
    }
}
