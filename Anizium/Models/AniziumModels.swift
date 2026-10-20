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

    public init(
        ID: String,
        name: String? = nil,
        number: StringOrNumber? = nil,
        overview: String? = nil,
        release: String? = nil,
        run_time: StringOrNumber? = nil,
        quality: String? = nil,
        banner_link: String? = nil,
        next_episode: String? = nil,
        download: Bool? = nil
    ) {
        self.ID = ID
        self.name = name
        self.number = number
        self.overview = overview
        self.release = release
        self.run_time = run_time
        self.quality = quality
        self.banner_link = banner_link
        self.next_episode = next_episode
        self.download = download
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

// MARK: - Authentication & User Models
public struct LoginResponse: Codable {
    public let success: Bool?
    public let isError: Bool?
    public let msg: String?
    public let message: String?
    public let statusCode: Int?
    public let session: String?
}

public struct UserProfileResponse: Codable {
    public let success: Bool?
    public let data: UserProfile?
}

public struct PremiumInfo: Codable {
    public let created: Int64?
    public let time: Int64?
    public let active: Bool?
}

public struct PremiumPlan: Codable {
    public let ID: String?
    public let name: String?
}

public struct UserProfile: Codable, Identifiable {
    public var id: String { self.ID ?? "" }
    public let ID: String?
    public let nick: String?
    public let email: String?
    public let name: String?
    public let surname: String?
    public let phone: String?
    public let subscription: Bool?
    public let premium: PremiumInfo?
    public let premium_plan: PremiumPlan?
    public let infinity: Bool?
    public let staff: Bool?
    public let profiles: [ProfileItem]?

    public var isPremium: Bool {
        if infinity == true { return true }
        guard let p = premium, p.active == true, let t = p.time, let c = p.created else {
            return false
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let remainingMs = t - (now - c)
        return remainingMs > 0 || t > 8640000000000
    }

    public var remainingPremiumText: String {
        guard let p = premium, let t = p.time, let c = p.created else {
            return "Yok"
        }
        if infinity == true {
            return "Sonsuz (Ömür Boyu)"
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let remainingMs = t - (now - c)
        if remainingMs <= 0 {
            return "Süresi Bitti"
        }
        let sec = (remainingMs / 1000) % 60
        let min = (remainingMs / 60000) % 60
        let hr = (remainingMs / 3600000) % 24
        let day = (remainingMs / 86400000) % 365
        let yr = remainingMs / 31536000000

        if yr > 50 {
            return "Sonsuz (Ömür Boyu)"
        }

        var parts: [String] = []
        if yr > 0 { parts.append("\(yr) yıl") }
        if day > 0 { parts.append("\(day) gün") }
        if hr > 0 { parts.append("\(hr) saat") }
        if min > 0 { parts.append("\(min) dakika") }
        if sec > 0 { parts.append("\(sec) saniye") }

        return parts.prefix(2).joined(separator: " ")
    }

    public var planDisplayName: String {
        if infinity == true {
            return "Sonsuz (Infinity)"
        }
        return premium_plan?.name ?? "Standart"
    }
}

// MARK: - Official Premium Plans Models
public struct PremiumPageResponse: Codable {
    public let success: Bool?
    public let data: [PremiumPlanData]?
}

public struct PremiumPlanData: Codable, Identifiable {
    public var id: String { value ?? "\(planId ?? 0)" }
    public let planId: Int?
    public let value: String?
    public let plan: String?
    public let active: Bool?
    public let name: String?
    public let day_text: String?
    public let day: Int64?
    public let view_price: Double?
    public let price: Double?
    public let renewal_price: Double?
    public let discount: PlanDiscount?
    public let advantages: [String]?
    public let alternatives: [PlanAlternative]?

    enum CodingKeys: String, CodingKey {
        case planId = "ID"
        case value
        case plan
        case active
        case name
        case day_text
        case day
        case view_price
        case price
        case renewal_price
        case discount
        case advantages
        case alternatives
    }

    public var isInfinity: Bool {
        value == "infinity" || (day ?? 0) > 3650
    }
}

public struct PlanDiscount: Codable {
    public let active: Bool?
    public let percent: Int?
    public let original_price: Double?
}

public struct PlanAlternative: Codable, Identifiable {
    public var id: String { "\(self.idField ?? "")_\(link)" }
    public let idField: String?
    public let link: String

    enum CodingKeys: String, CodingKey {
        case idField = "id"
        case link
    }

    public var platformName: String {
        switch idField {
        case "itemsatis": return "İtemsatış"
        case "shopier": return "Shopier"
        case "gumroad": return "Gumroad"
        default: return idField?.capitalized ?? "Satın Al"
        }
    }
}

public struct ProfileItem: Codable, Identifiable, Hashable {
    public var id: String { self.ID ?? self.name ?? UUID().uuidString }
    public let ID: String?
    public let name: String?
    public let avatar: String?
    public let avatar_link: String?
    public let adult: Bool?
    public let pin: Bool?

    public var displayAvatar: String? {
        avatar_link ?? avatar
    }
}

// MARK: - Keep Watching Models
public struct KeepWatchingResponse: Codable {
    public let success: Bool?
    public let data: [KeepWatchingItem]?
}

public struct KeepWatchingItem: Codable, Identifiable, Hashable {
    public var id: String { self.ID }
    public let ID: String
    public let type: String?
    public let logo: String?
    public let banner: String?
    public let details_banner: String?
    public let poster: String?
    public let name: String?
    public let sef: String?
    public let status: String?
    public let run_time: StringOrNumber?
    public let time: Double?
    public let updated: Int64?
    public let season: Int?
    public let episode: Int?

    public var isMovie: Bool {
        type == "movie"
    }

    public var progress: Double {
        guard let current = time, let totalMinutes = Double(run_time?.stringValue ?? "0"), totalMinutes > 0 else {
            return 0
        }
        let totalSeconds = totalMinutes * 60.0
        return min(max(current / totalSeconds, 0.0), 1.0)
    }

    public var displaySubtitle: String {
        if isMovie {
            let m = Int(time ?? 0) / 60
            return "Film • \(m) dk"
        } else {
            let m = Int(time ?? 0) / 60
            return "S\(season ?? 1) B\(episode ?? 1) • \(m) dk"
        }
    }
}

// MARK: - Comments Models
public struct CommentListResponse: Codable {
    public let success: Bool?
    public let page: CommentPage?
}

public struct CommentPage: Codable {
    public let page: StringOrNumber?
    public let total_pages: StringOrNumber?
    public let data: [CommentItem]?
}

public struct CommentItem: Codable, Identifiable {
    public var id: String { self.ID ?? UUID().uuidString }
    public let ID: String?
    public let message: String?
    public let spoiler: Bool?
    public let user_nick: String?
    public let profile_name: String?
    public let profile_avatar: String?
    public let like: StringOrNumber?
    public let dislike: StringOrNumber?
    public let created: StringOrNumber?
    public let replys: [CommentItem]?
}

// MARK: - Weekly Release Calendar Models
public struct CalendarResponse: Codable {
    public let success: Bool?
    public let data: [CalendarDay]?
}

public struct CalendarDay: Codable, Identifiable {
    public var id: String { self.title ?? self.day_name ?? UUID().uuidString }
    public let idField: String?
    public let title: String?
    public let month_name: String?
    public let day_name: String?
    public let contents: [CalendarItem]?

    enum CodingKeys: String, CodingKey {
        case idField = "id"
        case title
        case month_name
        case day_name
        case contents
    }
}

public struct CalendarItem: Codable, Identifiable {
    public var id: String { self.content_id ?? self.ID ?? self._id ?? UUID().uuidString }
    public let _id: String?
    public let ID: String?
    public let content_id: String?
    public let content_type: String?
    public let content: CalendarContent?

    public var animeCard: AnimeCard {
        AnimeCard(
            ID: self.content_id ?? self.ID ?? "",
            name: self.content?.name,
            poster: self.content?.poster,
            banner: self.content?.banner,
            banner_link: self.content?.details_banner ?? self.content?.banner,
            logo: self.content?.logo,
            quality: "4k",
            type: self.content_type,
            tmdb_point: nil,
            imdb_point: nil,
            mal_point: nil,
            episode_count: nil,
            series: self.content_type,
            total_season: nil,
            release_year: nil
        )
    }
}

public struct CalendarContent: Codable {
    public let name: String?
    public let logo: String?
    public let banner: String?
    public let details_banner: String?
    public let poster: String?
}

// MARK: - Random Anime
public struct RandomAnimeResponse: Codable {
    public let success: Bool?
    public let id: StringOrNumber?
}

// MARK: - Avatar Models
public struct AvatarListResponse: Codable {
    public let success: Bool?
    public let page: AvatarPage?
}

public struct AvatarPage: Codable {
    public let page: Int?
    public let next_page: Int?
    public let data: [AvatarGroup]?
}

public struct AvatarGroup: Codable, Identifiable {
    public var id: String { self.group_id ?? self.name ?? UUID().uuidString }
    public let group_id: String?
    public let name: String?
    public let logo: String?
    public let avatar: [AvatarItem]?

    enum CodingKeys: String, CodingKey {
        case group_id = "ID"
        case name
        case logo
        case avatar
    }
}

public struct AvatarItem: Codable, Identifiable, Hashable {
    public var id: String { self.item_id ?? self.avatar_set ?? UUID().uuidString }
    public let item_id: String?
    public let name: String?
    public let link: String?
    public let avatar_set: String?
    public let who_use: String?

    enum CodingKeys: String, CodingKey {
        case item_id = "ID"
        case name
        case link
        case avatar_set
        case who_use
    }
}
