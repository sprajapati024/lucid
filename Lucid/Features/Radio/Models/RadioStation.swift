import Foundation
import SwiftData

@Model
final class RadioStation {
    @Attribute(.unique) var stationuuid: String
    var name: String
    var url: String
    var urlResolved: String?
    var favicon: String?
    var tags: String
    var country: String
    var countryCode: String
    var state: String?
    var language: String?
    var codec: String
    var bitrate: Int
    var geoLat: Double?
    var geoLong: Double?
    var clickcount: Int
    var votes: Int
    var lastCheckOk: Bool
    var isFavorite: Bool = false
    var dateAdded: Date?
    var lastPlayed: Date?
    var cachedAt: Date

    init(
        stationuuid: String,
        name: String,
        url: String,
        urlResolved: String? = nil,
        favicon: String? = nil,
        tags: String,
        country: String,
        countryCode: String,
        state: String? = nil,
        language: String? = nil,
        codec: String,
        bitrate: Int,
        geoLat: Double? = nil,
        geoLong: Double? = nil,
        clickcount: Int,
        votes: Int,
        lastCheckOk: Bool,
        isFavorite: Bool = false,
        dateAdded: Date? = nil,
        lastPlayed: Date? = nil,
        cachedAt: Date = Date()
    ) {
        self.stationuuid = stationuuid
        self.name = name
        self.url = url
        self.urlResolved = urlResolved
        self.favicon = favicon
        self.tags = tags
        self.country = country
        self.countryCode = countryCode
        self.state = state
        self.language = language
        self.codec = codec
        self.bitrate = bitrate
        self.geoLat = geoLat
        self.geoLong = geoLong
        self.clickcount = clickcount
        self.votes = votes
        self.lastCheckOk = lastCheckOk
        self.isFavorite = isFavorite
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.cachedAt = cachedAt
    }

    var displayURL: String {
        urlResolved ?? url
    }

    var topTag: String? {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { !$0.isEmpty }
    }

    var hasGeo: Bool {
        geoLat != nil && geoLong != nil
    }

    var flagEmoji: String {
        RadioCountry.flagEmoji(for: countryCode)
    }
}
