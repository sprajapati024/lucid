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

struct RadioBrowserStation: Codable {
    let stationuuid: String
    let name: String
    let url: String
    let urlResolved: String?
    let favicon: String?
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
    private let modelContext: ModelContext
    private let session: URLSession
    private let baseURL = URL(string: "https://de1.api.radio-browser.info/json/")!
    private let decoder: JSONDecoder
    private var lastAPICallAt: Date?

    init(modelContext: ModelContext, session: URLSession = .shared) {
        self.modelContext = modelContext
        self.session = session
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchCountries() async throws -> [RadioCountry] {
        let cached = try fetchCachedCountries()
        if !cached.isEmpty, cached.allSatisfy({ !CacheExpiry.isExpired($0.cachedAt, for: .countries) }) {
            return cached
        }

        let countries: [RadioBrowserCountry] = try await request(path: "countries")

        guard !countries.isEmpty else {
            throw RadioBrowserError.noResults
        }

        let cachedAt = Date()
        let models = countries
            .filter { !$0.countryCode.isEmpty }
            .map { apiCountry in
                upsertCountry(apiCountry, cachedAt: cachedAt)
            }

        try saveContext()
        return models.sorted { $0.countryName.localizedCaseInsensitiveCompare($1.countryName) == .orderedAscending }
    }

    func fetchStations(forCountryCode code: String, hideBroken: Bool = true) async throws -> [RadioStation] {
        let normalizedCode = code.uppercased()
        let cached = try fetchCachedStations(countryCode: normalizedCode)

        if !cached.isEmpty, cached.first.map({ !CacheExpiry.isExpired($0.cachedAt, for: .stations) }) == true {
            return cached
        }

        let stations: [RadioBrowserStation] = try await request(
            path: "stations/bycountrycodeexact/\(normalizedCode)",
            queryItems: stationFilterItems(hideBroken: hideBroken)
        )

        guard !stations.isEmpty else {
            throw RadioBrowserError.noResults
        }

        let models = upsertStations(stations)
        try saveContext()
        return models
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

        let models = stations.map { $0.radioStation() }
        guard !models.isEmpty else {
            throw RadioBrowserError.noResults
        }

        return models
    }

    func getStation(uuid: String) async throws -> RadioStation {
        if let cached = try fetchCachedStation(uuid: uuid),
           !CacheExpiry.isExpired(cached.cachedAt, for: .stations) {
            return cached
        }

        let stations: [RadioBrowserStation] = try await request(path: "stations/byuuid/\(uuid)")
        guard let station = stations.first else {
            throw RadioBrowserError.noResults
        }

        let model = upsertStation(station, cachedAt: Date())
        try saveContext()
        return model
    }

    func getRandomStation() async throws -> RadioStation {
        let stations: [RadioBrowserStation] = try await request(
            path: "stations",
            queryItems: stationFilterItems(hideBroken: true, limit: 1, random: true)
        )

        guard let station = stations.first else {
            throw RadioBrowserError.noResults
        }

        return station.radioStation()
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
            let minimumInterval: TimeInterval = 0.5
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

    private func fetchCachedCountries() throws -> [RadioCountry] {
        let descriptor = FetchDescriptor<RadioCountry>(
            sortBy: [SortDescriptor(\.countryName)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchCachedStations(countryCode: String) throws -> [RadioStation] {
        let descriptor = FetchDescriptor<RadioStation>(
            predicate: #Predicate { station in
                station.countryCode == countryCode && station.lastCheckOk
            },
            sortBy: [SortDescriptor(\.clickcount, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchCachedStation(uuid: String) throws -> RadioStation? {
        var descriptor = FetchDescriptor<RadioStation>(
            predicate: #Predicate { station in
                station.stationuuid == uuid
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func upsertCountry(_ apiCountry: RadioBrowserCountry, cachedAt: Date) -> RadioCountry {
        if let existing = try? fetchCachedCountry(countryCode: apiCountry.countryCode) {
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
        modelContext.insert(country)
        return country
    }

    private func fetchCachedCountry(countryCode: String) throws -> RadioCountry? {
        var descriptor = FetchDescriptor<RadioCountry>(
            predicate: #Predicate { country in
                country.countryCode == countryCode
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func upsertStations(_ stations: [RadioBrowserStation]) -> [RadioStation] {
        let cachedAt = Date()
        return stations.map { upsertStation($0, cachedAt: cachedAt) }
    }

    private func upsertStation(_ apiStation: RadioBrowserStation, cachedAt: Date) -> RadioStation {
        if let existing = try? fetchCachedStation(uuid: apiStation.stationuuid) {
            existing.apply(apiStation, cachedAt: cachedAt)
            return existing
        }

        let station = apiStation.radioStation(cachedAt: cachedAt)
        modelContext.insert(station)
        return station
    }

    private func saveContext() throws {
        do {
            try modelContext.save()
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
            lastCheckOk: lastCheckOk ?? false,
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
        lastCheckOk = apiStation.lastCheckOk ?? false
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
