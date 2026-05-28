import MapKit
import SwiftUI

struct RadioGlobeView: View {
    @Bindable var viewModel: RadioGlobeViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isShowingFavorites = false
    @State private var isShowingRecent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                ZStack(alignment: .top) {
                    Map(position: $cameraPosition) {
                        ForEach(viewModel.countries) { country in
                            if let coordinate = country.mapCoordinate {
                                let isSelected = country.countryCode == viewModel.selectedCountry?.countryCode
                                let fillColor = isSelected ? Color.lucidGreen : country.mapColor

                                MapCircle(center: coordinate, radius: 800_000)
                                    .foregroundStyle(fillColor.opacity(isSelected ? 1.0 : 0.5))

                                MapCircle(center: coordinate, radius: 800_000)
                                    .stroke(.white, lineWidth: isSelected ? 4 : 2)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .ignoresSafeArea()
                    .onTapGesture(coordinateSpace: .local) { point in
                        dismissSearchResults()

                        guard let coordinate = proxy.convert(point, from: .local),
                              let country = country(at: coordinate) else {
                            return
                        }

                        viewModel.selectCountry(country)
                    }

                    searchOverlay { country in
                        fly(to: country)
                        viewModel.selectCountry(country)
                        dismissSearchResults()
                    }
                }
            }

            bottomBar
        }
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 3) {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))

                    if viewModel.isOffline {
                        Text("Check your connection")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 12)
                .padding(.horizontal)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingRecent = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Recently played")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        isShowingFavorites = true
                    } label: {
                        Image(systemName: "heart")
                    }
                    .accessibilityLabel("Favorites")

                    Button {
                        viewModel.selectRandomCountry()
                        if let country = viewModel.selectedCountry {
                            fly(to: country)
                        }
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .disabled(viewModel.countries.isEmpty)
                    .accessibilityLabel("Random country")
                }
            }
        }
        .sheet(isPresented: $isShowingFavorites) {
            FavoritesSheet()
        }
        .sheet(isPresented: $isShowingRecent) {
            RecentSheet()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 4) {
            Text("\(viewModel.countries.count) countries — tap to explore")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func searchOverlay(onSelect: @escaping (RadioCountry) -> Void) -> some View {
        VStack(spacing: 8) {
            searchBar

            if viewModel.isOffline {
                offlineBanner
            }

            if !viewModel.filteredCountries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.filteredCountries) { country in
                        Button {
                            onSelect(country)
                        } label: {
                            HStack(spacing: 10) {
                                Text(country.flagEmoji)
                                Text(country.countryName)
                                    .foregroundStyle(.lucidWhite)
                                Spacer()
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if country.persistentModelID != viewModel.filteredCountries.last?.persistentModelID {
                            Divider()
                                .overlay(Color.white.opacity(0.12))
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search countries...", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.lucidWhite)

            if !viewModel.searchText.isEmpty {
                Button {
                    dismissSearchResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    private var offlineBanner: some View {
        Label("You're offline - showing cached countries", systemImage: "wifi.slash")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
    }

    private func country(at coordinate: CLLocationCoordinate2D) -> RadioCountry? {
        let latDelta = 15.0
        let lngDelta = 15.0

        return viewModel.countries.first { country in
            guard let center = country.mapCoordinate else { return false }

            return center.latitude - latDelta <= coordinate.latitude
                && coordinate.latitude <= center.latitude + latDelta
                && center.longitude - lngDelta <= coordinate.longitude
                && coordinate.longitude <= center.longitude + lngDelta
        }
    }

    private func fly(to country: RadioCountry) {
        let center = country.mapCoordinate ?? CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
        )

        withAnimation(.easeInOut(duration: 0.7)) {
            cameraPosition = .region(region)
        }
    }

    private func dismissSearchResults() {
        viewModel.searchText = ""
    }
}

private extension RadioCountry {
    var mapCoordinate: CLLocationCoordinate2D? {
        CountryCoordinates.centers[countryCode.uppercased()].map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var mapColor: Color {
        let text = "\(countryName) \(countryCode)".lowercased()

        if text.contains("news") {
            return .gray
        }

        if text.contains("talk") {
            return .orange
        }

        if text.contains("mixed") {
            return .purple
        }

        if text.contains("music") {
            return .blue
        }

        switch abs(countryCode.hashValue) % 5 {
        case 0:
            return .blue
        case 1:
            return .gray
        case 2:
            return .purple
        case 3:
            return .orange
        default:
            return .green
        }
    }
}

private enum CountryCoordinates {
    static let centers: [String: (latitude: Double, longitude: Double)] = [
        "AD": (42.5, 1.6), "AE": (24.0, 54.0), "AF": (33.0, 65.0), "AG": (17.05, -61.8),
        "AL": (41.0, 20.0), "AM": (40.0, 45.0), "AO": (-12.5, 18.5), "AR": (-34.0, -64.0),
        "AT": (47.3, 13.3), "AU": (-25.0, 133.0), "AZ": (40.5, 47.5), "BA": (44.0, 18.0),
        "BB": (13.2, -59.5), "BD": (24.0, 90.0), "BE": (50.8, 4.5), "BF": (13.0, -2.0),
        "BG": (43.0, 25.0), "BH": (26.0, 50.55), "BI": (-3.5, 30.0), "BJ": (9.5, 2.25),
        "BN": (4.5, 114.7), "BO": (-17.0, -65.0), "BR": (-10.0, -55.0), "BS": (24.25, -76.0),
        "BT": (27.5, 90.5), "BW": (-22.0, 24.0), "BY": (53.0, 28.0), "BZ": (17.25, -88.75),
        "CA": (60.0, -95.0), "CD": (0.0, 25.0), "CF": (7.0, 21.0), "CG": (-1.0, 15.0),
        "CH": (47.0, 8.0), "CI": (8.0, -5.0), "CL": (-30.0, -71.0), "CM": (6.0, 12.0),
        "CN": (35.0, 105.0), "CO": (4.0, -72.0), "CR": (10.0, -84.0), "CU": (21.5, -80.0),
        "CV": (16.0, -24.0), "CY": (35.0, 33.0), "CZ": (49.75, 15.5), "DE": (51.0, 9.0),
        "DJ": (11.5, 43.0), "DK": (56.0, 10.0), "DO": (19.0, -70.7), "DZ": (28.0, 3.0),
        "EC": (-2.0, -77.5), "EE": (59.0, 26.0), "EG": (27.0, 30.0), "ES": (40.0, -4.0),
        "ET": (8.0, 38.0), "FI": (64.0, 26.0), "FJ": (-18.0, 175.0), "FR": (46.0, 2.0),
        "GA": (-1.0, 11.75), "GB": (54.0, -2.0), "GD": (12.1, -61.7), "GE": (42.0, 43.5),
        "GH": (8.0, -2.0), "GM": (13.5, -15.5), "GN": (11.0, -10.0), "GQ": (2.0, 10.0),
        "GR": (39.0, 22.0), "GT": (15.5, -90.25), "GW": (12.0, -15.0), "GY": (5.0, -59.0),
        "HN": (15.0, -86.5), "HR": (45.2, 15.5), "HT": (19.0, -72.4), "HU": (47.0, 20.0),
        "ID": (-5.0, 120.0), "IE": (53.0, -8.0), "IL": (31.5, 34.75), "IN": (20.0, 77.0),
        "IQ": (33.0, 44.0), "IR": (32.0, 53.0), "IS": (65.0, -18.0), "IT": (42.8, 12.8),
        "JM": (18.25, -77.5), "JO": (31.0, 36.0), "JP": (36.0, 138.0), "KE": (1.0, 38.0),
        "KG": (41.0, 75.0), "KH": (13.0, 105.0), "KM": (-12.2, 44.25), "KP": (40.0, 127.0),
        "KR": (37.0, 127.5), "KW": (29.5, 47.75), "KZ": (48.0, 68.0), "LA": (18.0, 105.0),
        "LB": (33.8, 35.8), "LC": (13.9, -61.0), "LI": (47.16, 9.55), "LK": (7.0, 81.0),
        "LR": (6.5, -9.5), "LS": (-29.5, 28.5), "LT": (56.0, 24.0), "LU": (49.75, 6.17),
        "LV": (57.0, 25.0), "LY": (25.0, 17.0), "MA": (32.0, -5.0), "MC": (43.73, 7.42),
        "MD": (47.0, 29.0), "ME": (42.7, 19.3), "MG": (-20.0, 47.0), "MK": (41.6, 21.7),
        "ML": (17.0, -4.0), "MM": (22.0, 98.0), "MN": (46.0, 105.0), "MR": (20.0, -12.0),
        "MT": (35.9, 14.4), "MU": (-20.3, 57.55), "MV": (3.25, 73.0), "MW": (-13.5, 34.0),
        "MX": (23.0, -102.0), "MY": (2.5, 112.5), "MZ": (-18.25, 35.0), "NA": (-22.0, 17.0),
        "NE": (16.0, 8.0), "NG": (10.0, 8.0), "NI": (13.0, -85.0), "NL": (52.5, 5.75),
        "NO": (62.0, 10.0), "NP": (28.0, 84.0), "NZ": (-41.0, 174.0), "OM": (21.0, 57.0),
        "PA": (9.0, -80.0), "PE": (-10.0, -76.0), "PG": (-6.0, 147.0), "PH": (13.0, 122.0),
        "PK": (30.0, 70.0), "PL": (52.0, 20.0), "PT": (39.5, -8.0), "PY": (-23.0, -58.0),
        "QA": (25.5, 51.25), "RO": (46.0, 25.0), "RS": (44.0, 21.0), "RU": (60.0, 100.0),
        "RW": (-2.0, 30.0), "SA": (25.0, 45.0), "SC": (-4.6, 55.45), "SD": (15.0, 30.0),
        "SE": (62.0, 15.0), "SG": (1.37, 103.8), "SI": (46.0, 15.0), "SK": (48.7, 19.5),
        "SL": (8.5, -11.5), "SM": (43.94, 12.46), "SN": (14.0, -14.0), "SO": (10.0, 49.0),
        "SR": (4.0, -56.0), "SV": (13.8, -88.9), "SY": (35.0, 38.0), "SZ": (-26.5, 31.5),
        "TD": (15.0, 19.0), "TG": (8.0, 1.17), "TH": (15.0, 100.0), "TJ": (39.0, 71.0),
        "TL": (-8.8, 126.0), "TN": (34.0, 9.0), "TR": (39.0, 35.0), "TT": (11.0, -61.0),
        "TW": (23.5, 121.0), "TZ": (-6.0, 35.0), "UA": (49.0, 32.0), "UG": (1.0, 32.0),
        "US": (39.8, -98.6), "UY": (-33.0, -56.0), "UZ": (41.0, 64.0), "VA": (41.9, 12.45),
        "VE": (8.0, -66.0), "VN": (16.0, 106.0), "YE": (15.0, 48.0), "ZA": (-29.0, 24.0),
        "ZM": (-15.0, 30.0), "ZW": (-20.0, 30.0)
    ]
}
