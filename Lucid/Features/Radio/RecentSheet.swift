import SwiftData
import SwiftUI

struct RecentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<RadioStation> { station in
            station.lastPlayed != nil
        }
    ) private var recentStations: [RadioStation]

    @Query(sort: \RadioCountry.countryName) private var countries: [RadioCountry]
    @Query private var cachedStations: [RadioStation]

    @State private var selectedStationCountry: RecentStationCountrySelection?

    private var visibleRecentStations: [RadioStation] {
        Array(
            recentStations
                .sorted {
                    ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast)
                }
                .prefix(20)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleRecentStations.isEmpty {
                    emptyState
                } else {
                    List(visibleRecentStations) { station in
                        StationRowView(station: station) {
                            selectedStationCountry = selection(for: station)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recently Played")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                sheetHeader
            }
            .sheet(item: $selectedStationCountry) { selection in
                CountryStationSheet(
                    country: selection.country,
                    highlightedStationUUID: selection.stationUUID
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        if cachedStations.isEmpty {
            EmptyStateView(
                icon: "wifi.slash",
                title: "You're Offline",
                message: "Recently played stations will appear once stations have been cached on this device."
            )
        } else {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "No Recent Stations",
                message: "Start listening to build your recent history"
            )
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 4) {
            Text("🕐 Recently Played")
                .font(.title2.weight(.bold))
                .foregroundStyle(.lucidWhite)

            Text("\(visibleRecentStations.count) \(visibleRecentStations.count == 1 ? "station" : "stations")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private func selection(for station: RadioStation) -> RecentStationCountrySelection {
        let country = countries.first { $0.countryCode == station.countryCode }
            ?? RadioCountry(
                countryCode: station.countryCode,
                countryName: station.country.isEmpty ? station.countryCode : station.country,
                stationCount: 0
            )

        return RecentStationCountrySelection(country: country, stationUUID: station.stationuuid)
    }
}

private struct RecentStationCountrySelection: Identifiable {
    let id = UUID()
    let country: RadioCountry
    let stationUUID: String
}
