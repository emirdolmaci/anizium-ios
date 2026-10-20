import Foundation

// MARK: - Home Models
public struct HomeResponse: Codable {
    public let success: Bool?
    public let settlement_top: [SettlementItem]?
    public let settlement_middle: [SettlementItem]?
    public let settlement_lower: [SettlementItem]?
    public let special_list: [SpecialList]?
}

public struct SettlementItem: Codable, Identifiable, Hashable {
    public var id: String { ID }
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
    public let release_year: Int?
    public let tmdb_point: String?
    public let imdb_point: String?
    public let mal_point: String?
    public let category: String?
}

public struct SpecialList: Codable, Identifiable {
    public let id: String
    public let name: String
    public let data: [AnimeCard]
}

public struct AnimeCard: Codable, Identifiable, Hashable {
    public var id: String { ID }
    public let ID: String
    public let name: String?
    public let poster: String?
    public let banner_link: String?
    public let quality: String?
    public let tmdb_point: String?
    public let mal_point: String?
    public let episode_count: Int?
    public let series: String?
    public let total_season: Int?
    public let release_year: Int?
}

// MARK: - Anime Detail Models
public struct AnimeDetailResponse: Codable {
    public let success: Bool?
    public let data: AnimeDetail?
}

public struct AnimeDetail: Codable, Identifiable {
    public var id: String { ID }
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
    public let release_year: Int?
    public let run_time: Int?
    public let tmdb_point: String?
    public let imdb_point: String?
    public let mal_point: String?
    public let anilist_point: String?
    public let seasons: [Season]?
    public let total_season: Int?
}

public struct Season: Codable, Identifiable {
    public var id: String { ID }
    public let ID: String
    public let name: String?
    public let number: Int?
    public let overview: String?
    public let release: String?
    public let episodes: [Episode]?
}

public struct Episode: Codable, Identifiable {
    public var id: String { ID }
    public let ID: String
    public let name: String?
    public let number: Int
    public let overview: String?
    public let release: String?
    public let run_time: Int?
    public let quality: String?
    public let banner_link: String?
    public let next_episode: String?
    public let download: Bool?
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
    public let season: Int?
    public let episode: Int?
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
    public let season: Int?
    public let episode: Int?
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
    public let quality: Int
    public let link: String
    public let type: String?
}

public struct SubtitleItem: Codable, Identifiable {
    public var id: String { link }
    public let group: String?
    public let name: String?
    public let link: String
    public let row: Int?
}

// MARK: - Search Models
public struct SearchResponse: Codable {
    public let success: Bool?
    public let page: PaginatedPage?
}

public struct PaginatedPage: Codable {
    public let page: Int?
    public let total_pages: Int?
    public let data: [AnimeCard]?
}
