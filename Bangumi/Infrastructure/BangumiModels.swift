import Foundation

struct BangumiToken: Codable {
  let accessToken: String
  let tokenType: String
  let expiresIn: Int
  let refreshToken: String?
  let userID: Int?

  var authorizationHeader: String {
    "\(tokenType) \(accessToken)"
  }
}

struct BangumiUser: Codable, Identifiable {
  let id: Int
  let username: String
  let nickname: String?
  let avatar: BangumiImages?
  let sign: String?

  var displayName: String {
    if let nickname, !nickname.isEmpty {
      return nickname
    }
    return username
  }
}

struct BangumiImages: Codable {
  let large: String?
  let common: String?
  let medium: String?
  let small: String?

  var best: URL? {
    BangumiRemoteURL.url(from: large ?? common ?? medium ?? small)
  }
}

enum BangumiRemoteURL {
  static func url(from raw: String?) -> URL? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if trimmed.hasPrefix("//") {
      return URL(string: "https:\(trimmed)")
    }

    if trimmed.hasPrefix("http://") {
      return URL(string: "https://" + trimmed.dropFirst("http://".count))
    }

    return URL(string: trimmed)
  }
}

struct BangumiRating: Codable {
  let score: Double?
  let rank: Int?
  let total: Int?
}

struct BangumiTag: Codable, Hashable {
  let name: String
  let count: Int?
}

struct BangumiSubjectSummary: Codable, Identifiable {
  let id: Int
  let type: Int?
  let name: String
  let nameCN: String?
  let images: BangumiImages?
  let eps: Int?
  let totalEpisodes: Int?
  let date: String?
  let rating: BangumiRating?
  let searchMeta: String?

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case name
    case nameCN = "name_cn"
    case images
    case eps
    case totalEpisodes = "total_episodes"
    case date
    case rating
    case searchMeta = "search_meta"
  }

  init(
    id: Int,
    type: Int?,
    name: String,
    nameCN: String?,
    images: BangumiImages?,
    eps: Int?,
    totalEpisodes: Int?,
    date: String?,
    rating: BangumiRating?,
    searchMeta: String? = nil
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.nameCN = nameCN
    self.images = images
    self.eps = eps
    self.totalEpisodes = totalEpisodes
    self.date = date
    self.rating = rating
    self.searchMeta = searchMeta
  }
}

struct BangumiSubject: Codable, Identifiable {
  let id: Int
  let type: Int?
  let name: String
  let nameCN: String?
  let summary: String?
  let images: BangumiImages?
  let eps: Int?
  let totalEpisodes: Int?
  let volumes: Int?
  let platform: String?
  let date: String?
  let rating: BangumiRating?
  let tags: [BangumiTag]?
  let locked: Bool?
  let nsfw: Bool?
  let collection: BangumiSubjectCollectionStats?

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case name
    case nameCN = "name_cn"
    case summary
    case images
    case eps
    case totalEpisodes = "total_episodes"
    case volumes
    case platform
    case date
    case rating
    case tags
    case locked
    case nsfw
    case collection
  }
}

struct BangumiSubjectCollectionStats: Codable {
  let doing: Int?
  let collect: Int?
  let wish: Int?
  let onHold: Int?
  let dropped: Int?

  enum CodingKeys: String, CodingKey {
    case doing
    case collect
    case wish
    case onHold = "on_hold"
    case dropped
  }
}

struct BangumiEpisode: Codable, Identifiable {
  let id: Int
  let name: String?
  let nameCN: String?
  let sort: Double?
  let airdate: String?
  let status: String?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case nameCN = "name_cn"
    case sort
    case airdate
    case status
  }
}

enum BangumiEpisodeCollectionType: Int, Codable, CaseIterable, Hashable {
  case none = 0
  case wish = 1
  case watched = 2
  case dropped = 3

  var title: String {
    switch self {
    case .none: "未标记"
    case .wish: "想看"
    case .watched: "看过"
    case .dropped: "抛弃"
    }
  }
}

struct BangumiEpisodeCollection: Identifiable, Hashable {
  let episodeID: Int
  let type: BangumiEpisodeCollectionType
  let updatedAt: Int?

  var id: Int { episodeID }
}

enum BangumiNotificationPermissionState: String, Codable, CaseIterable, Identifiable {
  case notDetermined
  case denied
  case authorized
  case provisional
  case ephemeral

  var id: String { rawValue }

  var title: String {
    switch self {
    case .notDetermined: "尚未授权"
    case .denied: "通知已关闭"
    case .authorized: "通知已开启"
    case .provisional: "已静默授权"
    case .ephemeral: "临时授权"
    }
  }

  var subtitle: String {
    switch self {
    case .notDetermined: "开启条目提醒时会请求系统通知权限。"
    case .denied: "请前往系统设置允许 Bangumi 发送通知。"
    case .authorized: "检测到新章节后会直接推送到系统通知中心。"
    case .provisional: "系统会以较轻量的方式呈现提醒。"
    case .ephemeral: "当前处于临时授权状态。"
    }
  }

  var systemImage: String {
    switch self {
    case .notDetermined: "bell.badge"
    case .denied: "bell.slash"
    case .authorized: "bell.badge.fill"
    case .provisional: "bell.and.waves.left.and.right"
    case .ephemeral: "bell.circle"
    }
  }

  var canDeliverNotifications: Bool {
    switch self {
    case .authorized, .provisional, .ephemeral: true
    case .notDetermined, .denied: false
    }
  }
}

struct BangumiSubjectNotificationSubscription: Codable, Identifiable, Hashable {
  let subjectID: Int
  var title: String
  var subtitle: String?
  var coverURLString: String?
  var subjectTypeTitle: String?
  var latestEpisodeID: Int?
  var latestEpisodeSort: Double?
  var latestEpisodeAirdate: String?
  var latestEpisodeTitle: String?
  var lastKnownEpisodeCount: Int
  var isEnabled: Bool
  var createdAt: Date
  var updatedAt: Date
  var lastCheckedAt: Date?
  var lastNotifiedEpisodeID: Int?
  var lastErrorMessage: String?

  var id: Int { subjectID }

  var coverURL: URL? {
    BangumiRemoteURL.url(from: coverURLString)
  }

  var latestEpisodeLabel: String {
    if let latestEpisodeSort {
      if latestEpisodeSort.rounded(.towardZero) == latestEpisodeSort {
        return "第 \(Int(latestEpisodeSort)) 集"
      }
      return "第 \(latestEpisodeSort.formatted(.number.precision(.fractionLength(1)))) 集"
    }
    if let latestEpisodeID {
      return "章节 #\(latestEpisodeID)"
    }
    return "暂无章节基线"
  }
}

struct BangumiSubjectUpdateCheckResult {
  let subjectID: Int
  let hasUpdate: Bool
  let latestEpisode: BangumiEpisode?
  let checkedAt: Date
  let errorMessage: String?
}

struct BangumiEpisodeCollectionsPageResponse: Codable {
  let total: Int?
  let data: [BangumiUserEpisodeCollectionDTO]
}

struct BangumiUserEpisodeCollectionDTO: Codable {
  struct EpisodeReference: Codable {
    let id: Int
  }

  let episode: EpisodeReference
  let type: Int
  let updatedAt: Int?

  enum CodingKeys: String, CodingKey {
    case episode
    case type
    case updatedAt = "updated_at"
  }

  func collection() -> BangumiEpisodeCollection {
    BangumiEpisodeCollection(
      episodeID: episode.id,
      type: BangumiEpisodeCollectionType(rawValue: type) ?? .none,
      updatedAt: updatedAt
    )
  }
}

struct BangumiCalendarDay: Codable, Identifiable {
  let weekday: BangumiWeekday
  let items: [BangumiSubjectSummary]

  var id: Int { weekday.id }
}

struct BangumiWeekday: Codable {
  let id: Int
  let cn: String
}

struct BangumiCollectionsResponse: Codable {
  let total: Int?
  let data: [BangumiCollectionItem]
}

struct SearchResponse: Codable {
  let list: [BangumiSubjectSummary]

  enum CodingKeys: String, CodingKey {
    case list
  }

  init(list: [BangumiSubjectSummary]) {
    self.list = list
  }

  init(from decoder: Decoder) throws {
    if let single = try? decoder.singleValueContainer().decode([BangumiSubjectSummary].self) {
      self.list = single
      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.list = try container.decodeIfPresent([BangumiSubjectSummary].self, forKey: .list) ?? []
  }
}

struct OAuthTokenDTO: Codable {
  let accessToken: String
  let expiresIn: Int
  let refreshToken: String?
  let tokenType: String
  let userID: Int?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
    case tokenType = "token_type"
    case userID = "user_id"
  }
}

struct EmptyResponse: Codable {}

enum BangumiError: LocalizedError {
  case invalidURL
  case missingToken
  case missingCurrentUser
  case invalidResponse
  case oauthCancelled
  case oauthMissingCode
  case oauthClientSecretMissing

  var errorDescription: String? {
    switch self {
    case .invalidURL: "URL 无效"
    case .missingToken: "当前未登录"
    case .missingCurrentUser: "当前用户信息缺失，请重新登录"
    case .invalidResponse: "服务返回异常"
    case .oauthCancelled: "登录已取消"
    case .oauthMissingCode: "未能从回调中解析授权码"
    case .oauthClientSecretMissing: "未配置 OAuth Client Secret，请改用 Token 登录或在应用配置中注入密钥"
    }
  }
}
