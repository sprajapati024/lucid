import Foundation

enum CacheType {
    case countries
    case stations
}

enum CacheExpiry {
    static let countries: TimeInterval = 7 * 24 * 60 * 60
    static let stations: TimeInterval = 3 * 24 * 60 * 60

    static func isExpired(_ date: Date, for type: CacheType) -> Bool {
        let threshold = type == .countries ? Self.countries : Self.stations
        return Date().timeIntervalSince(date) > threshold
    }
}
