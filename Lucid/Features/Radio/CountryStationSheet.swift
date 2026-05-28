import SwiftData
import SwiftUI

struct CountryStationSheet: View {
    let country: RadioCountry

    @Environment(\.modelContext) private var modelContext
    @State private var stations: [RadioStation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showComingSoonAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if stations.isEmpty {
                    ContentUnavailableView(
                        "No Stations",
                        systemImage: "radio",
                        description: Text("No stations are available for this country yet.")
                    )
                } else {
                    List(stations) { station in
                        StationRowView(station: station) {
                            showComingSoonAlert = true
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(country.flagEmoji) \(country.countryName)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                header
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await fetchStations()
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Playback will be added in Phase 4")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 2) {
                Text(country.countryName)
                    .font(.headline)
                Text(country.countryCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(stations.isEmpty ? country.stationCount : stations.count)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.lucidGreen.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.lucidGreen)
                .accessibilityLabel("\(stations.isEmpty ? country.stationCount : stations.count) stations")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await fetchStations()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fetchStations() async {
        isLoading = true
        errorMessage = nil

        do {
            stations = try await RadioBrowserService(modelContext: modelContext)
                .fetchStations(forCountryCode: country.countryCode)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct StationRowView: View {
    @Environment(\.modelContext) private var modelContext

    var station: RadioStation
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                RadioBrowserService(modelContext: modelContext).toggleFavorite(station)
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
    }

    private var details: String {
        [
            station.topTag,
            station.codec.isEmpty ? nil : station.codec,
            station.bitrate > 0 ? "\(station.bitrate) kbps" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }
}
