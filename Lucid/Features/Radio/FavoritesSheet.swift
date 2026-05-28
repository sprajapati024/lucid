import SwiftData
import SwiftUI

struct FavoritesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<RadioStation> { station in
            station.isFavorite
        }
    ) private var favoriteStations: [RadioStation]

    @Query(sort: \RadioCountry.countryName) private var countries: [RadioCountry]
    @Query private var cachedStations: [RadioStation]

    @State private var selectedStationCountry: FavoriteStationCountrySelection?

    private var sortedFavoriteStations: [RadioStation] {
        favoriteStations.sorted {
            ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedFavoriteStations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sortedFavoriteStations) { station in
                            StationRowView(station: station) {
                                selectedStationCountry = selection(for: station)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                unfavoriteStation(sortedFavoriteStations[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
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
                message: "Favorites will appear here once stations have been cached on this device."
            )
        } else {
            EmptyStateView(
                icon: "heart",
                title: "No Favorites",
                message: "No favorites yet - tap the heart on any station to save it here"
            )
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 4) {
            Text("❤️ Favorites")
                .font(.title2.weight(.bold))
                .foregroundStyle(.lucidWhite)

            Text("\(sortedFavoriteStations.count) \(sortedFavoriteStations.count == 1 ? "station" : "stations")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private func unfavoriteStation(_ station: RadioStation) {
        station.isFavorite = false
        station.dateAdded = nil

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            print("Failed to unfavorite station: \(error)")
        }
    }

    private func selection(for station: RadioStation) -> FavoriteStationCountrySelection {
        let country = countries.first { $0.countryCode == station.countryCode }
            ?? RadioCountry(
                countryCode: station.countryCode,
                countryName: station.country.isEmpty ? station.countryCode : station.country,
                stationCount: 0
            )

        return FavoriteStationCountrySelection(country: country, stationUUID: station.stationuuid)
    }
}

private struct FavoriteStationCountrySelection: Identifiable {
    let id = UUID()
    let country: RadioCountry
    let stationUUID: String
}
