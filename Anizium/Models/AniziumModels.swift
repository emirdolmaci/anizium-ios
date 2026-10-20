import Foundation

// MARK: - Lossless String / Number Decoder Helper
public struct StringOrNumber: Codable, Hashable, CustomStringConvertible {
    public let stringValue: String?

    public var description: String {
        return stringValue ?? ""
    }

    public init(_ stringValue: String?) {
        self.stringValue = stringValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.stringValue = nil
        } else if let s = try? container.decode(String.self) {
            self.stringValue = s
        } else if let i = try? container.decode(Int.self) {
            self.stringValue = String(i)
        } else if let d = try? container.decode(Double.self) {
            self.stringValue = d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(format: "%.1f", d)
        } else if let b = try? container.decode(Bool.self) {
            self.stringValue = String(b)
        } else {
            self.stringValue = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

extension StringOrNumber: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.stringValue = value
    }
}

extension StringOrNumber: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.stringValue = String(value)
    }
}

// MARK: - Home Models
public struct HomeResponse: Codable {
    public let success: Bool?
    public let settlement_top: [SettlementItem]?
    public let settlement_middle: [SettlementItem]?
    public let settlement_lower: [SettlementItem]?
    public let special_list: [SpecialList]?
}

public struct SettlementItem: Codable, Identifiable, Hashable {
    public var id: String { self.ID }
    public let ID: String
    public let type: String?
    public let logo: String?
    public let banner: String?
    public let details_banner: String?
    public let poster: String?
    public let mobile_poster_link: String?
    public let name: String?
    public let overview: String?
    public let overview_short: String?
    public let status: String?
    public let quality: String?
    public let release_year: StringOrNumber?
    public let tmdb_point: StringOrNumber?
    public let imdb_point: StringOrNumber?
    public let mal_point: StringOrNumber?

    public var rating: String? {
        tmdb_point?.stringValue ?? imdb_point?.stringValue ?? mal_point?.stringValue
    }
}

public struct SpecialList: Codable, Identifiable {
    public let id: String
    public let name: String
    public let data: [AnimeCard]
}

public struct AnimeCard: Codable, Identifiable, Hashable {
    public var id: String { self.ID }
    public let ID: String
    public let name: String?
    public let poster: String?
    public let banner: String?
    public let banner_link: String?
    public let logo: String?
    public let quality: String?
    public let type: String?
    public let tmdb_point: StringOrNumber?
    public let imdb_point: StringOrNumber?
    public let mal_point: StringOrNumber?
    public let episode_count: StringOrNumber?
    public let series: String?
    public let total_season: StringOrNumber?
    public let release_year: StringOrNumber?

    public var rating: String? {
        tmdb_point?.stringValue ?? imdb_point?.stringValue ?? mal_point?.stringValue
    }

    public var posterURLString: String? {
        banner_link ?? poster ?? banner
    }
}

// MARK: - Anime Detail Models
public struct AnimeDetailResponse: Codable {
    public let success: Bool?
    public let data: AnimeDetail?
}

public struct AnimeDetail: Codable, Identifiable {
    public var id: String { self.ID }
    public let ID: String
    public let type: String?
    public let logo: String?
    public let banner: String?
    public let details_banner: String?
    public let poster: String?
    public let mobile_poster_link: String?
    public let name: String?
    public let name_jp: String?
    public let name_tr: String?
    public let overview: String?
    public let overview_short: String?
    public let tagline: String?
    public let status: String?
    public let quality: String?
    public let youtube_video: String?
    public let release_year: StringOrNumber?
    public let run_time: StringOrNumber?
    public let tmdb_point: StringOrNumber?
    public let imdb_point: StringOrNumber?
    public let mal_point: StringOrNumber?
    public let anilist_point: StringOrNumber?
    public let seasons: [Season]?
    public let total_season: StringOrNumber?

    public var rating: String? {
        tmdb_point?.stringValue ?? imdb_point?.stringValue ?? mal_point?.stringValue ?? anilist_point?.stringValue
    }
}

public struct Season: Codable, Identifiable {
    public var id: String { self.ID }
    public let ID: String
    public let name: String?
    public let number: StringOrNumber?
    public let overview: String?
    public let release: String?
    public let episodes: [Episode]?

    public var seasonNumber: Int {
        if let s = number?.stringValue, let i = Int(s) { return i }
        return 1
    }
}

public struct Episode: Codable, Identifiable {
    public var id: String { self.ID }
    public let ID: String
    public let name: String?
    public let number: StringOrNumber?
    public let overview: String?
    public let release: String?
    public let run_time: StringOrNumber?
    public let quality: String?
    public let banner_link: String?
    public let next_episode: String?
    public let download: Bool?

    public var episodeNumber: Int {
        if let s = number?.stringValue, let i = Int(s) { return i }
        return 1
    }
}

// MARK: - Streaming Video Source Models
public struct SourceResponse: Codable {
    public let success: Bool?
    public let content: SourceContent?
    public let groups: [SourceGroup]?
    public let subtitles: [SubtitleItem]?
}

public struct SourceContent: Codable {
    public let name: String?
    public let type: String?
    public let season: StringOrNumber?
    public let episode: StringOrNumber?
    public let next_episode: String?
    public let next_episode_end: String?
    public let finish: String?
    public let opening: OpeningTime?
    public let next_episode_data: NextEpisodeData?
}

public struct OpeningTime: Codable {
    public let start: String?
    public let end: String?
}

public struct NextEpisodeData: Codable {
    public let season: StringOrNumber?
    public let episode: StringOrNumber?
    public let link: String?
}

public struct SourceGroup: Codable, Identifiable {
    public var id: String { "\(platform ?? "")_\(group ?? "")" }
    public let platform: String?
    public let group: String?
    public let name: String?
    public let type: String?
    public let items: [StreamItem]?
}

public struct StreamItem: Codable, Identifiable {
    public var id: String { link }
    public let quality: StringOrNumber?
    public let link: String
    public let type: String?

    public var qualityInt: Int {
        if let q = quality?.stringValue, let i = Int(q) { return i }
        return 1080
    }
}

public struct SubtitleItem: Codable, Identifiable {
    public var id: String { link }
    public let group: String?
    public let name: String?
    public let link: String
    public let row: StringOrNumber?
}

// MARK: - Search Models
public struct SearchResponse: Codable {
    public let success: Bool?
    public let page: PaginatedPage?
}

public struct PaginatedPage: Codable {
    public let page: StringOrNumber?
    public let total_pages: StringOrNumber?
    public let data: [AnimeCard]?
}
