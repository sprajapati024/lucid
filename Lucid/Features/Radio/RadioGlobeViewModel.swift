import MapKit
import Observation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class RadioGlobeViewModel {
    var countries: [RadioCountry] = []
    var selectedCountry: RadioCountry?
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    private let service: RadioBrowserService

    init(modelContext: ModelContext) {
        service = RadioBrowserService(modelContext: modelContext)

        Task {
            await loadCountries()
        }
    }

    var filteredCountries: [RadioCountry] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return [] }

        return Array(
            countries
                .filter { $0.countryName.localizedCaseInsensitiveContains(trimmedSearch) }
                .prefix(5)
        )
    }

    func loadCountries() async {
        isLoading = true
        errorMessage = nil

        do {
            countries = try await service.fetchCountries()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectCountry(_ country: RadioCountry) {
        selectedCountry = country
    }

    func clearSelection() {
        selectedCountry = nil
    }

    func selectRandomCountry() {
        guard let country = countries.randomElement() else { return }
        selectCountry(country)
    }
}
