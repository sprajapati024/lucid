import Foundation
import SwiftData

@Model
final class RadioCountry {
    @Attribute(.unique) var countryCode: String
    var countryName: String
    var stationCount: Int
    var cachedAt: Date

    init(
        countryCode: String,
        countryName: String,
        stationCount: Int,
        cachedAt: Date = Date()
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.stationCount = stationCount
        self.cachedAt = cachedAt
    }

    var flagEmoji: String {
        Self.flagEmoji(for: countryCode)
    }

    static func flagEmoji(for countryCode: String) -> String {
        let scalars = countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { scalar -> UnicodeScalar? in
                guard scalar.value >= 65, scalar.value <= 90 else {
                    return nil
                }
                return UnicodeScalar(127397 + scalar.value)
            }

        guard scalars.count == 2 else {
            return ""
        }

        return String(String.UnicodeScalarView(scalars))
    }
}
