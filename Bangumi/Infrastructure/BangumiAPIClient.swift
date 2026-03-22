import Foundation

final class BangumiAPIClient {
  struct Config {
    let apiBase = URL(string: "https://api.bgm.tv")!
    let apiV0Base = URL(string: "https://api.bgm.tv/v0")!
    let webBase = URL(string: "https://bgm.tv")!
    let nextBase = URL(string: "https://next.bgm.tv/p1")!
    let appID = "bgm8885c4d524cd61fc"
    let callbackURL = URL(string: "https://bgm.tv/dev/app")!

    var appSecret: String? {
      let environmentSecret = ProcessInfo.processInfo.environment["BANGUMI_OAUTH_CLIENT_SECRET"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if let environmentSecret, !environmentSecret.isEmpty {
        return environmentSecret
      }

      let plistSecret = Bundle.main.object(forInfoDictionaryKey: "BangumiOAuthClientSecret") as? String
      let trimmedSecret = plistSecret?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let trimmedSecret, !trimmedSecret.isEmpty {
        return trimmedSecret
      }

      return nil
    }
  }

  let config = Config()
  private let sessionStore: BangumiSessionStore
  private let urlSession: URLSession
  private var activeOAuthSession: BangumiOAuthAuthorizationSession?

  init(sessionStore: BangumiSessionStore) {
    self.sessionStore = sessionStore

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .useProtocolCachePolicy
    configuration.urlCache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 30
    urlSession = URLSession(configuration: configuration)
  }

  func beginOAuthAuthorization() -> BangumiOAuthAuthorizationSession {
    let state = oauthState()
    var components = URLComponents(url: config.webBase.appending(path: "/oauth/authorize"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: config.appID),
      URLQueryItem(name: "redirect_uri", value: config.callbackURL.absoluteString),
      URLQueryItem(name: "state", value: state)
    ]

    let session = BangumiOAuthAuthorizationSession(
      authorizeURL: components.url!,
      callbackURL: config.callbackURL,
      state: state
    )
    activeOAuthSession = session
    return session
  }

  func cancelOAuthAuthorization() {
    activeOAuthSession = nil
  }

  func consumeOAuthCallback(_ url: URL) throws -> String {
    guard let session = activeOAuthSession else {
      throw BangumiError.oauthStateMismatch
    }

    defer {
      activeOAuthSession = nil
    }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    guard let callbackState = components?.queryItems?.first(where: { $0.name == "state" })?.value,
          !callbackState.isEmpty else {
      throw BangumiError.oauthStateMissing
    }

    guard callbackState == session.state else {
      throw BangumiError.oauthStateMismatch
    }

    guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
          !code.isEmpty else {
      throw BangumiError.oauthMissingCode
    }

    return code
  }

  func exchangeCodeForToken(code: String) async throws -> BangumiToken {
    guard let appSecret = config.appSecret else {
      throw BangumiError.oauthClientSecretMissing
    }

    var request = URLRequest(url: config.webBase.appending(path: "/oauth/access_token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = formData([
      "grant_type": "authorization_code",
      "client_id": config.appID,
      "client_secret": appSecret,
      "code": code,
      "redirect_uri": config.callbackURL.absoluteString
    ])

    let (data, response) = try await urlSession.data(for: request)
    try validate(response: response)
    let dto = try decode(OAuthTokenDTO.self, from: data)
    return BangumiToken(
      accessToken: dto.accessToken,
      tokenType: dto.tokenType,
      expiresIn: dto.expiresIn,
      refreshToken: dto.refreshToken,
      userID: dto.userID
    )
  }

  func fetchCurrentUser(using token: BangumiToken? = nil) async throws -> BangumiUser {
    try await get(url: config.apiV0Base.appending(path: "/me"), requiresAuth: true, tokenOverride: token)
  }

  func fetchCalendar() async throws -> [BangumiCalendarDay] {
    try await get(path: "/calendar")
  }

  func searchSubjects(keyword: String, type: SubjectType) async throws -> [BangumiSubjectSummary] {
    let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? keyword
    let response: SearchResponse = try await get(
      path: "/search/subject/\(encoded)",
      query: [
        URLQueryItem(name: "type", value: String(type.rawValue)),
        URLQueryItem(name: "max_results", value: "20"),
        URLQueryItem(name: "responseGroup", value: "small")
      ]
    )
    return response.list
  }

  func searchSubjectsFromWeb(keyword: String, type: SubjectType) async throws -> [BangumiSubjectSummary] {
    let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? keyword
    var components = URLComponents(url: config.webBase, resolvingAgainstBaseURL: false)
    components?.percentEncodedPath = "/subject_search/\(encoded)"
    components?.queryItems = [URLQueryItem(name: "cat", value: String(type.rawValue))]
    guard let finalURL = components?.url else {
      throw BangumiError.invalidURL
    }

    let html = try await fetchWebHTML(url: finalURL)
    return BangumiSubjectSearchWebParser.parse(html: html, baseURL: config.webBase)
  }

  func fetchSubject(id: Int) async throws -> BangumiSubject {
    do {
      let response: BangumiV0SubjectDTO = try await get(
        url: config.apiV0Base.appending(path: "/subjects/\(id)"),
        query: [URLQueryItem(name: "responseGroup", value: "small")]
      )
      return response.subject()
    } catch {
      let html = try await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(id)"))
      return BangumiSubjectWebParser.parse(html: html, id: id, baseURL: config.webBase)
    }
  }

  func fetchEpisodes(subjectID: Int) async throws -> [BangumiEpisode] {
    do {
      return try await fetchEpisodesFromV0(subjectID: subjectID)
    } catch {
      let html = try await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)"))
      return BangumiSubjectWebParser.parseEpisodes(html: html)
    }
  }

  func fetchCollection(subjectID: Int) async throws -> BangumiSubjectCollectionRecord {
    try await get(url: config.apiV0Base.appending(path: "/users/-/collections/\(subjectID)"), requiresAuth: true)
  }

  func fetchEpisodeCollections(subjectID: Int) async throws -> [BangumiEpisodeCollection] {
    let limit = 100
    var offset = 0
    var collections: [BangumiEpisodeCollection] = []

    while offset <= 2_000 {
      let response: BangumiEpisodeCollectionsPageResponse = try await get(
        url: config.apiV0Base.appending(path: "/users/-/collections/\(subjectID)/episodes"),
        query: [
          URLQueryItem(name: "limit", value: String(limit)),
          URLQueryItem(name: "offset", value: String(offset))
        ],
        requiresAuth: true
      )

      let page = response.data.map { $0.collection() }
      if page.isEmpty {
        break
      }

      collections.append(contentsOf: page)
      if page.count < limit {
        break
      }
      offset += limit
    }

    return collections
  }

  func fetchSubjectComments(subjectID: Int) async throws -> [BangumiSubjectComment] {
    let html = try await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)/comments"))
    return BangumiSubjectCommentsParser.parse(html: html, baseURL: config.webBase)
  }

  func fetchSubjectPresentation(subjectID: Int) async throws -> BangumiSubjectPresentation {
    async let subjectHTML = fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)"))
    async let charactersHTML: String? = try? await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)/characters"))
    async let staffHTML: String? = try? await fetchWebHTML(
      path: "/subject/\(subjectID)/persons",
      query: [URLQueryItem(name: "group", value: "person")]
    )
    async let relationsHTML: String? = try? await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)/relations"))

    return BangumiSubjectPresentationParser.parse(
      subjectHTML: try await subjectHTML,
      charactersHTML: await charactersHTML,
      staffHTML: await staffHTML,
      relationsHTML: await relationsHTML,
      subjectID: subjectID,
      baseURL: config.webBase
    )
  }

  func fetchWatchingCollections(
    userID: String,
    subjectType: SubjectType,
    limit: Int = 20
  ) async throws -> [BangumiCollectionItem] {
    let response: BangumiCollectionsResponse = try await get(
      url: config.apiV0Base.appending(path: "/users/\(userID)/collections"),
      query: [
        URLQueryItem(name: "subject_type", value: subjectType.rawValue.description),
        URLQueryItem(name: "type", value: CollectionStatus.doing.v0Type),
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: "0")
      ],
      requiresAuth: true
    )
    return response.data
  }

  func fetchUserProfile(userID: String) async throws -> BangumiUserProfile {
    let html = try await fetchWebHTML(url: config.webBase.appending(path: "/user/\(userID)"))
    return BangumiUserProfileParser.parse(html: html, userID: userID, baseURL: config.webBase)
  }

  func fetchTimeline(page: Int, filter: TimelineFilter) async throws -> BangumiTimelinePage {
    let html = try await fetchWebHTML(
      path: "/timeline",
      query: [
        URLQueryItem(name: "type", value: filter.rawValue),
        URLQueryItem(name: "page", value: String(page))
      ]
    )
    return BangumiTimelineParser.parse(html: html, page: page, baseURL: config.webBase)
  }

  func fetchTimelineDetail(url: URL) async throws -> BangumiTimelineDetail {
    let html = try await fetchWebHTML(url: url)
    return BangumiTimelineDetailParser.parse(html: html, baseURL: config.webBase)
  }

  func fetchRakuen(filter: RakuenFilter) async throws -> [BangumiRakuenItem] {
    let html = try await fetchWebHTML(
      path: "/rakuen/topiclist",
      query: [URLQueryItem(name: "type", value: filter.rawValue)]
    )
    return BangumiRakuenParser.parse(html: html, baseURL: config.webBase)
  }

  func fetchRakuenTopic(url: URL) async throws -> BangumiRakuenTopicDetail {
    let html = try await fetchWebHTML(url: url)
    return BangumiRakuenTopicParser.parse(html: html, baseURL: config.webBase)
  }

  func updateCollection(subjectID: Int, payload: CollectionUpdatePayload) async throws {
    _ = try await post(
      path: "/collection/\(subjectID)/update",
      form: [
        "status": payload.status.rawValue,
        "tags": payload.tags,
        "comment": payload.comment,
        "rating": String(payload.rating),
        "privacy": payload.isPrivate ? "1" : "0"
      ],
      requiresAuth: true
    ) as EmptyResponse
  }

  func updateEpisodeCollection(episodeID: Int, type: BangumiEpisodeCollectionType) async throws {
    struct Payload: Encodable {
      let type: Int
    }

    _ = try await sendJSON(
      url: config.apiV0Base.appending(path: "/users/-/collections/-/episodes/\(episodeID)"),
      method: "PUT",
      body: Payload(type: type.rawValue),
      requiresAuth: true
    ) as EmptyResponse
  }

  func markEpisodeWatched(episodeID: Int) async throws {
    _ = try await post(path: "/ep/\(episodeID)/status/watched", form: [:], requiresAuth: true) as EmptyResponse
  }

  func updateWatchedProgress(
    subjectID: Int,
    watchedEpisodes: Int? = nil,
    watchedVolumes: Int? = nil
  ) async throws {
    var form: [String: String] = [:]
    if let watchedEpisodes {
      form["watched_eps"] = String(watchedEpisodes)
    }
    if let watchedVolumes {
      form["watched_vols"] = String(watchedVolumes)
    }
    guard !form.isEmpty else { return }
    _ = try await post(
      path: "/subject/\(subjectID)/update/watched_eps",
      form: form,
      requiresAuth: true
    ) as EmptyResponse
  }

  func clearCaches() {
    urlSession.configuration.urlCache?.removeAllCachedResponses()
    URLCache.shared.removeAllCachedResponses()
  }

  private func get<T: Decodable>(
    path: String,
    query: [URLQueryItem] = [],
    requiresAuth: Bool = false,
    tokenOverride: BangumiToken? = nil
  ) async throws -> T {
    try await get(url: config.apiBase.appending(path: path), query: query, requiresAuth: requiresAuth, tokenOverride: tokenOverride)
  }

  private func get<T: Decodable>(
    url: URL,
    query: [URLQueryItem] = [],
    requiresAuth: Bool = false,
    tokenOverride: BangumiToken? = nil
  ) async throws -> T {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    var queryItems = query
    queryItems.append(URLQueryItem(name: "app_id", value: config.appID))
    components?.queryItems = queryItems

    guard let finalURL = components?.url else {
      throw BangumiError.invalidURL
    }

    var request = URLRequest(url: finalURL)
    request.httpMethod = "GET"
    request.cachePolicy = .useProtocolCachePolicy
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if requiresAuth {
      let token = tokenOverride ?? sessionStore.token
      guard let token else { throw BangumiError.missingToken }
      request.setValue(token.authorizationHeader, forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await urlSession.data(for: request)
    try validate(response: response)
    return try decode(T.self, from: data)
  }

  private func post<T: Decodable>(
    path: String,
    form: [String: String],
    requiresAuth: Bool
  ) async throws -> T {
    guard let token = sessionStore.token else {
      throw BangumiError.missingToken
    }

    var request = URLRequest(url: config.apiBase.appending(path: path))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue(token.authorizationHeader, forHTTPHeaderField: "Authorization")
    request.httpBody = formData(form)

    let (data, response) = try await urlSession.data(for: request)
    try validate(response: response)
    return try decode(T.self, from: data)
  }

  private func sendJSON<T: Decodable, Body: Encodable>(
    url: URL,
    method: String,
    body: Body,
    requiresAuth: Bool
  ) async throws -> T {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(body)

    if requiresAuth {
      guard let token = sessionStore.token else {
        throw BangumiError.missingToken
      }
      request.setValue(token.authorizationHeader, forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await urlSession.data(for: request)
    try validate(response: response)
    return try decode(T.self, from: data)
  }

  private func fetchWebHTML(path: String, query: [URLQueryItem]) async throws -> String {
    var components = URLComponents(url: config.webBase.appending(path: path), resolvingAgainstBaseURL: false)
    components?.queryItems = query

    guard let finalURL = components?.url else {
      throw BangumiError.invalidURL
    }

    return try await fetchWebHTML(url: finalURL)
  }

  private func fetchEpisodesFromV0(subjectID: Int) async throws -> [BangumiEpisode] {
    let limit = 100
    var offset = 0
    var episodes: [BangumiEpisode] = []

    while offset <= 2_000 {
      let response: BangumiV0EpisodesResponse = try await get(
        url: config.apiV0Base.appending(path: "/episodes"),
        query: [
          URLQueryItem(name: "subject_id", value: String(subjectID)),
          URLQueryItem(name: "type", value: "0"),
          URLQueryItem(name: "limit", value: String(limit)),
          URLQueryItem(name: "offset", value: String(offset))
        ]
      )
      let page = response.data.map { $0.episode() }
      if page.isEmpty {
        break
      }

      episodes.append(contentsOf: page)
      if page.count < limit {
        break
      }
      offset += limit
    }

    return episodes.sorted { lhs, rhs in
      (lhs.sort ?? .greatestFiniteMagnitude) < (rhs.sort ?? .greatestFiniteMagnitude)
    }
  }

  private func fetchWebHTML(url: URL) async throws -> String {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.cachePolicy = .reloadRevalidatingCacheData
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent"
    )
    request.setValue("zh-CN,zh-Hans;q=0.9,en;q=0.8,ja;q=0.7", forHTTPHeaderField: "Accept-Language")
    request.setValue(config.webBase.absoluteString, forHTTPHeaderField: "Referer")

    let (data, response) = try await urlSession.data(for: request)
    try validate(response: response)

    guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
      throw BangumiError.invalidResponse
    }

    return html
  }

  private func validate(response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw BangumiError.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      throw NSError(domain: "BangumiAPI", code: httpResponse.statusCode, userInfo: [
        NSLocalizedDescriptionKey: "请求失败（\(httpResponse.statusCode)）"
      ])
    }
  }

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    if T.self == EmptyResponse.self, data.isEmpty {
      return EmptyResponse() as! T
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    return try decoder.decode(T.self, from: data)
  }

  private func formData(_ values: [String: String]) -> Data {
    let body = values
      .compactMap { key, value -> String? in
        guard
          let encodedKey = formURLEncoded(key),
          let encodedValue = formURLEncoded(value)
        else {
          return nil
        }
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")
    return Data(body.utf8)
  }

  private func oauthState() -> String {
    UUID().uuidString
  }

  private func formURLEncoded(_ value: String) -> String? {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._* ")

    return value
      .addingPercentEncoding(withAllowedCharacters: allowed)?
      .replacingOccurrences(of: " ", with: "+")
  }
}
