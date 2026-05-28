import Foundation
import SwiftData

enum RadioBrowserError: LocalizedError {
    case networkError(String)
    case invalidResponse(String)
    case noResults
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Radio Browser network error: \(message)"
        case .invalidResponse(let message):
            return "Radio Browser returned an invalid response: \(message)"
        case .noResults:
            return "Radio Browser returned no results."
        case .rateLimited:
            return "Radio Browser rate limit reached. Try again later."
        }
    }
}

struct RadioBrowserStation: Decodable {
    let stationuuid: String
    let name: String
    let url: String
    let urlResolved: String?
    let favicon: String?
    let homepage: String?
    let tags: String?
    let country: String?
    let countryCode: String?
    let state: String?
    let language: String?
    let codec: String?
    let bitrate: Int?
    let geoLat: Double?
    let geoLong: Double?
    let clickcount: Int?
    let votes: Int?
    let lastCheckOk: Bool?

    enum CodingKeys: String, CodingKey {
        case stationuuid
        case name
        case url
        case urlResolved = "url_resolved"
        case favicon
        case tags
        case country
        case countryCode = "countrycode"
        case state
        case language
        case codec
        case bitrate
        case geoLat = "geo_lat"
        case geoLong = "geo_long"
        case clickcount
        case votes
        case lastCheckOk = "lastcheckok"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationuuid = try container.decode(String.self, forKey: .stationuuid)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        urlResolved = try container.decodeIfPresent(String.self, forKey: .urlResolved)
        favicon = try container.decodeIfPresent(String.self, forKey: .favicon)
        homepage = try container.decodeIfPresent(String.self, forKey: .url)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        codec = try container.decodeIfPresent(String.self, forKey: .codec)
        bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate)
        geoLat = try container.decodeIfPresent(Double.self, forKey: .geoLat)
        geoLong = try container.decodeIfPresent(Double.self, forKey: .geoLong)
        clickcount = try container.decodeIfPresent(Int.self, forKey: .clickcount)
        votes = try container.decodeIfPresent(Int.self, forKey: .votes)
        lastCheckOk = try container.decodeFlexibleBoolIfPresent(forKey: .lastCheckOk)
    }
}

struct RadioBrowserCountry: Codable {
    let countryName: String
    let countryCode: String
    let stationCount: Int

    enum CodingKeys: String, CodingKey {
        case countryName = "name"
        case countryCode = "iso_3166_1"
        case stationCount = "stationcount"
    }
}

@MainActor
final class RadioBrowserService {
    static let shared = RadioBrowserService(modelContext: nil)

    private let modelContext: ModelContext?
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private var lastAPICallAt: Date?
    private(set) var servedOfflineCache = false

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
        self.session = URLSession.shared
        guard let baseURL = URL(string: "https://de1.api.radio-browser.info/json/") else {
            fatalError("Invalid Radio Browser base URL")
        }
        self.baseURL = baseURL
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func withContext(_ context: ModelContext) -> RadioBrowserService {
        RadioBrowserService(modelContext: context)
    }

    func fetchCountries() async throws -> [RadioCountry] {
        guard let modelContext else {
            throw RadioBrowserError.invalidResponse("No ModelContext available")
        }

        servedOfflineCache = false
        let cached = try fetchCachedCountries(context: modelContext)
        if !cached.isEmpty, cached.first.map({ !CacheExpiry.isExpired($0.cachedAt, for: .countries) }) == true {
            return cached
        }

        let countries: [RadioBrowserCountry]
        do {
            countries = try await request(path: "countries")
        } catch RadioBrowserError.networkError where !cached.isEmpty {
            servedOfflineCache = true
            return cached
        } catch {
            throw error
        }

        guard !countries.isEmpty else {
            throw RadioBrowserError.noResults
        }

        let cachedAt = Date()
        let models = countries
            .filter { !$0.countryCode.isEmpty }
            .map { apiCountry in
                upsertCountry(apiCountry, cachedAt: cachedAt, context: modelContext)
            }

        try saveContext(context: modelContext)
        return models.sorted { $0.countryName.localizedCaseInsensitiveCompare($1.countryName) == .orderedAscending }
    }

    func fetchStations(forCountryCode code: String, hideBroken: Bool = true) async throws -> [RadioStation] {
        guard let modelContext else {
            throw RadioBrowserError.invalidResponse("No ModelContext available")
        }

        let normalizedCode = code.uppercased()
        let cached = try fetchCachedStations(countryCode: normalizedCode, context: modelContext)

        if !cached.isEmpty, cached.first.map({ !CacheExpiry.isExpired($0.cachedAt, for: .stations) }) == true {
            return cached
        }

        let stations: [RadioBrowserStation]
        do {
            stations = try await request(
                path: "stations/bycountrycodeexact/\(normalizedCode)",
                queryItems: stationFilterItems(hideBroken: hideBroken)
            )
        } catch RadioBrowserError.networkError where !cached.isEmpty {
            return cached
        } catch {
            throw error
        }

        guard !stations.isEmpty else {
            throw RadioBrowserError.noResults
        }

        let models = upsertStations(stations, context: modelContext)
        try saveContext(context: modelContext)
        return models
    }

    func refreshCountriesIfStale() async {
        guard let modelContext else { return }

        let cached = (try? fetchCachedCountries(context: modelContext)) ?? []
        var shouldRefreshCountries = true
        if !cached.isEmpty {
            let oldest = cached.map(\.cachedAt).min() ?? .distantPast
            if !CacheExpiry.isExpired(oldest, for: .countries) {
                shouldRefreshCountries = false
            }
        }

        if shouldRefreshCountries {
            _ = try? await fetchCountries()
        }
        await refreshStaleStationCaches()
    }

    func searchStations(query: String, limit: Int = 30) async throws -> [RadioStation] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw RadioBrowserError.noResults
        }

        let stations: [RadioBrowserStation] = try await request(
            path: "stations/byname/\(trimmedQuery)",
            queryItems: stationFilterItems(hideBroken: true, limit: limit)
        )

        let models: [RadioStation]
        if let modelContext {
            models = upsertStations(stations, context: modelContext)
            try saveContext(context: modelContext)
        } else {
            models = stations.map { $0.radioStation() }
        }

        guard !models.isEmpty else {
            throw RadioBrowserError.noResults
        }

        return models
    }

    func getStation(uuid: String) async throws -> RadioStation {
        guard let modelContext else {
            throw RadioBrowserError.invalidResponse("No ModelContext available")
        }

        if let cached = try fetchCachedStation(uuid: uuid, context: modelContext),
           !CacheExpiry.isExpired(cached.cachedAt, for: .stations) {
            return cached
        }

        let stations: [RadioBrowserStation] = try await request(path: "stations/byuuid/\(uuid)")
        guard let station = stations.first else {
            throw RadioBrowserError.noResults
        }

        let model = upsertStation(station, cachedAt: Date(), context: modelContext)
        try saveContext(context: modelContext)
        return model
    }

    func getRandomStation() async throws -> RadioStation {
        guard let modelContext else {
            throw RadioBrowserError.invalidResponse("No ModelContext available")
        }

        let stations: [RadioBrowserStation] = try await request(
            path: "stations",
            queryItems: stationFilterItems(hideBroken: true, limit: 1, random: true)
        )

        guard let station = stations.first else {
            throw RadioBrowserError.noResults
        }

        let model = upsertStation(station, cachedAt: Date(), context: modelContext)
        try saveContext(context: modelContext)
        return model
    }

    func reportStationClick(uuid: String) async throws {
        let _: RadioBrowserClickResponse = try await request(
            path: "url/\(uuid)",
            method: "POST"
        )
    }

    func fetchStationsNear(lat: Double, long: Double, radiusKm: Int = 500) async throws -> [RadioStation] {
        let stations: [RadioBrowserStation] = try await request(
            path: "stations/search",
            queryItems: stationFilterItems(hideBroken: true) + [
                URLQueryItem(name: "geo_lat", value: String(lat)),
                URLQueryItem(name: "geo_long", value: String(long)),
                URLQueryItem(name: "geo_distance", value: String(radiusKm * 1_000))
            ]
        )

        let models = stations.map { $0.radioStation() }
        guard !models.isEmpty else {
            throw RadioBrowserError.noResults
        }

        return models
    }

    func toggleFavorite(_ station: RadioStation) {
        station.isFavorite.toggle()
        station.dateAdded = station.isFavorite ? Date() : nil

        if let modelContext {
            try? modelContext.save()
        }
    }

    private func refreshStaleStationCaches() async {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<RadioStation>()
        let stations = (try? modelContext.fetch(descriptor)) ?? []
        let groupedByCountry = Dictionary(grouping: stations) { $0.countryCode }

        for (countryCode, cachedStations) in groupedByCountry where !countryCode.isEmpty {
            let oldest = cachedStations.map(\.cachedAt).min() ?? .distantPast
            if CacheExpiry.isExpired(oldest, for: .stations) {
                _ = try? await fetchStations(forCountryCode: countryCode)
            }
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        try await waitForRateLimitWindow()

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw RadioBrowserError.invalidResponse("Could not build URL for \(path).")
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("LucidRadio/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RadioBrowserError.invalidResponse("Missing HTTP response.")
            }

            switch httpResponse.statusCode {
            case 200..<300:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw RadioBrowserError.invalidResponse(error.localizedDescription)
                }
            case 429:
                throw RadioBrowserError.rateLimited
            default:
                throw RadioBrowserError.invalidResponse("HTTP \(httpResponse.statusCode).")
            }
        } catch let error as RadioBrowserError {
            throw error
        } catch {
            throw RadioBrowserError.networkError(error.localizedDescription)
        }
    }

    private func waitForRateLimitWindow() async throws {
        if let lastAPICallAt {
            let elapsed = Date().timeIntervalSince(lastAPICallAt)
            let minimumInterval: TimeInterval = 2.0
            if elapsed < minimumInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumInterval - elapsed) * 1_000_000_000))
            }
        }
        lastAPICallAt = Date()
    }

    private func stationFilterItems(
        hideBroken: Bool,
        limit: Int? = nil,
        random: Bool = false
    ) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "hidebroken", value: hideBroken ? "true" : "false"),
            URLQueryItem(name: "order", value: random ? "random" : "clickcount"),
            URLQueryItem(name: "reverse", value: "true")
        ]

        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return items
    }

    private func fetchCachedCountries(context: ModelContext) throws -> [RadioCountry] {
        let descriptor = FetchDescriptor<RadioCountry>(
            sortBy: [SortDescriptor(\.countryName)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchCachedStations(countryCode: String, context: ModelContext) throws -> [RadioStation] {
        let descriptor = FetchDescriptor<RadioStation>(
            predicate: #Predicate { station in
                station.countryCode == countryCode
            },
            sortBy: [SortDescriptor(\.clickcount, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchCachedStation(uuid: String, context: ModelContext) throws -> RadioStation? {
        var descriptor = FetchDescriptor<RadioStation>(
            predicate: #Predicate { station in
                station.stationuuid == uuid
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func upsertCountry(_ apiCountry: RadioBrowserCountry, cachedAt: Date, context: ModelContext) -> RadioCountry {
        if let existing = try? fetchCachedCountry(countryCode: apiCountry.countryCode, context: context) {
            existing.countryName = apiCountry.countryName
            existing.stationCount = apiCountry.stationCount
            existing.cachedAt = cachedAt
            return existing
        }

        let country = RadioCountry(
            countryCode: apiCountry.countryCode,
            countryName: apiCountry.countryName,
            stationCount: apiCountry.stationCount,
            cachedAt: cachedAt
        )
        context.insert(country)
        return country
    }

    private func fetchCachedCountry(countryCode: String, context: ModelContext) throws -> RadioCountry? {
        var descriptor = FetchDescriptor<RadioCountry>(
            predicate: #Predicate { country in
                country.countryCode == countryCode
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func upsertStations(_ stations: [RadioBrowserStation], context: ModelContext) -> [RadioStation] {
        let cachedAt = Date()
        return stations.map { upsertStation($0, cachedAt: cachedAt, context: context) }
    }

    private func upsertStation(_ apiStation: RadioBrowserStation, cachedAt: Date, context: ModelContext) -> RadioStation {
        if let existing = try? fetchCachedStation(uuid: apiStation.stationuuid, context: context) {
            existing.apply(apiStation, cachedAt: cachedAt)
            return existing
        }

        let station = apiStation.radioStation(cachedAt: cachedAt)
        context.insert(station)
        return station
    }

    private func saveContext(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw RadioBrowserError.invalidResponse("Failed to save radio cache: \(error.localizedDescription)")
        }
    }
}

private struct RadioBrowserClickResponse: Codable {}

private extension RadioBrowserStation {
    func radioStation(cachedAt: Date = Date()) -> RadioStation {
        RadioStation(
            stationuuid: stationuuid,
            name: name,
            url: url,
            urlResolved: urlResolved?.nilIfEmpty,
            favicon: favicon?.nilIfEmpty,
            homepage: homepage?.nilIfEmpty ?? "",
            tags: tags ?? "",
            country: country ?? "",
            countryCode: countryCode?.uppercased() ?? "",
            state: state?.nilIfEmpty,
            language: language?.nilIfEmpty,
            codec: codec ?? "",
            bitrate: bitrate ?? 0,
            geoLat: geoLat,
            geoLong: geoLong,
            clickcount: clickcount ?? 0,
            votes: votes ?? 0,
            lastCheckOk: lastCheckOk ?? true,
            cachedAt: cachedAt
        )
    }
}

private extension RadioStation {
    func apply(_ apiStation: RadioBrowserStation, cachedAt: Date) {
        name = apiStation.name
        url = apiStation.url
        urlResolved = apiStation.urlResolved?.nilIfEmpty
        favicon = apiStation.favicon?.nilIfEmpty
        homepage = apiStation.homepage?.nilIfEmpty ?? ""
        tags = apiStation.tags ?? ""
        country = apiStation.country ?? ""
        countryCode = apiStation.countryCode?.uppercased() ?? ""
        state = apiStation.state?.nilIfEmpty
        language = apiStation.language?.nilIfEmpty
        codec = apiStation.codec ?? ""
        bitrate = apiStation.bitrate ?? 0
        geoLat = apiStation.geoLat
        geoLong = apiStation.geoLong
        clickcount = apiStation.clickcount ?? 0
        votes = apiStation.votes ?? 0
        lastCheckOk = apiStation.lastCheckOk ?? true
        self.cachedAt = cachedAt
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        return nil
    }
}
