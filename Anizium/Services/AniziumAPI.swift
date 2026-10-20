import Foundation
import Combine

public enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError(Int)
    case apiMessage(String)
    case decodingError(Error)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz URL adresi."
        case .serverError(let code): return "Sunucu hatası (\(code))."
        case .apiMessage(let msg): return msg
        case .decodingError(let err): return "Veri işleme hatası: \(err.localizedDescription)"
        case .emptyResponse: return "Boş sunucu yanıtı."
        }
    }
}

public final class AniziumAPI: ObservableObject {
    public static let shared = AniziumAPI()
    private let baseURL = "https://api.anizium.online"
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Reverse-engineered Cf-Control cryptographic header generator
    public func generateCfControl() -> String {
        var calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "Europe/Istanbul") ?? TimeZone.current
        calendar.timeZone = tz
        let now = Date()

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = tz
        dateFormatter.dateFormat = "EEEE"
        let dayName = dateFormatter.string(from: now).lowercased()

        let chars = "0123456789abcdefghijklmnopqrstuvwxyz"
        let randKey = String((0..<6).compactMap { _ in chars.randomElement() })
        let millis = Int64(now.timeIntervalSince1970 * 1000)

        let jsonPayload = "{\"\(randKey)\":\(millis)}"
        let xorKeyString = "hlxjl1c2w281ax473rt1ofgrvhyjvi_\(dayName)"

        guard let payloadBytes = jsonPayload.data(using: .utf8),
              let keyBytes = xorKeyString.data(using: .utf8) else {
            return ""
        }

        let keyArray = [UInt8](keyBytes)
        let payloadArray = [UInt8](payloadBytes)
        var hexString = ""

        for (index, byte) in payloadArray.enumerated() {
            let keyByte = keyArray[index % keyArray.count]
            let xorVal = byte ^ keyByte
            hexString += String(format: "%02x", xorVal)
        }
        return hexString
    }

    private func createRequest(path: String, method: String = "GET", queryItems: [URLQueryItem]? = nil, body: Data? = nil) -> URLRequest? {
        guard var components = URLComponents(string: "\(baseURL)/\(path)") else {
            return nil
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.GitHub.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Anizium/2.1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue(generateCfControl(), forHTTPHeaderField: "Cf-Control")

        if let userSession = UserDefaults.standard.string(forKey: "user_session"), !userSession.isEmpty {
            request.setValue(userSession, forHTTPHeaderField: "user-session")
        }
        request.httpBody = body
        return request
    }

    // MARK: - Authentication
    public func login(value: String, password: String) async throws -> LoginResponse {
        let bodyDict = ["value": value, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        guard let request = createRequest(path: "user/login", method: "POST", body: bodyData) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = (errObj["msg"] as? String) ?? (errObj["message"] as? String) {
                throw APIError.apiMessage(msg)
            }
            throw APIError.serverError(http.statusCode)
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func register(username: String, email: String, password: String) async throws -> LoginResponse {
        let bodyDict = ["username": username, "email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        guard let request = createRequest(path: "user/register", method: "POST", body: bodyData) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = (errObj["msg"] as? String) ?? (errObj["message"] as? String) {
                throw APIError.apiMessage(msg)
            }
            throw APIError.serverError(http.statusCode)
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func fetchUser() async throws -> UserProfile {
        guard let request = createRequest(path: "user/get") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        let res = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        guard let u = res.data else { throw APIError.emptyResponse }
        return u
    }

    // MARK: - Core Media
    public func fetchHome() async throws -> HomeResponse {
        guard let request = createRequest(path: "page/home") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(HomeResponse.self, from: data)
        } catch {
            print("Home decode error: \(error)")
            throw APIError.decodingError(error)
        }
    }

    public func fetchAnimeDetail(id: String) async throws -> AnimeDetail {
        let query = [URLQueryItem(name: "id", value: id)]
        guard let request = createRequest(path: "anime/get", queryItems: query) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        let res = try JSONDecoder().decode(AnimeDetailResponse.self, from: data)
        guard let detail = res.data else { throw APIError.emptyResponse }
        return detail
    }

    public func fetchSource(id: String, season: Int, episode: Int) async throws -> SourceResponse {
        let query = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "season", value: "\(season)"),
            URLQueryItem(name: "episode", value: "\(episode)")
        ]
        guard let request = createRequest(path: "anime/source", queryItems: query) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        return try JSONDecoder().decode(SourceResponse.self, from: data)
    }

    public func search(query: String, page: Int = 1) async throws -> [AnimeCard] {
        let queryItems = [
            URLQueryItem(name: "value", value: query),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        guard let request = createRequest(path: "page/search", queryItems: queryItems) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        let res = try JSONDecoder().decode(SearchResponse.self, from: data)
        return res.page?.data ?? []
    }

    // MARK: - Weekly Calendar (Yayın Takvimi)
    public func fetchCalendar() async throws -> [CalendarDay] {
        guard let request = createRequest(path: "page/calendar") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        let res = try JSONDecoder().decode(CalendarResponse.self, from: data)
        return res.data ?? []
    }

    // MARK: - Random Anime (Rastgele)
    public func fetchRandomAnimeId() async throws -> String {
        guard let request = createRequest(path: "page/random-anime") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
        let res = try JSONDecoder().decode(RandomAnimeResponse.self, from: data)
        guard let id = res.id?.stringValue, !id.isEmpty else {
            throw APIError.emptyResponse
        }
        return id
    }

    // MARK: - Comments
    public func fetchComments(animeId: String, page: Int = 1) async throws -> [CommentItem] {
        let queryItems = [
            URLQueryItem(name: "id", value: animeId),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "type", value: "series"),
            URLQueryItem(name: "sort", value: "new")
        ]
        guard let request = createRequest(path: "comment/list", queryItems: queryItems) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return []
        }
        let res = try? JSONDecoder().decode(CommentListResponse.self, from: data)
        return res?.page?.data ?? []
    }

    public func sendComment(animeId: String, message: String, spoiler: Bool) async throws {
        let bodyDict: [String: Any] = [
            "anime": animeId,
            "message": message,
            "spoiler": spoiler
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        guard let request = createRequest(path: "comment/send", method: "POST", body: bodyData) else {
            throw APIError.invalidURL
        }
        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.serverError(http.statusCode)
        }
    }
}
