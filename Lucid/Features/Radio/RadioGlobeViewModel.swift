import MapKit
import Observation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class RadioGlobeViewModel {
    var countries: [RadioCountry] = []
    var selectedCountry: RadioCountry?
    var isLoading = false
    var errorMessage: String?

    private let service: RadioBrowserService

    init(modelContext: ModelContext) {
        service = RadioBrowserService(modelContext: modelContext)

        Task {
            await loadCountries()
        }
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
