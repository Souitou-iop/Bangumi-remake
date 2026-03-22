import BackgroundTasks
import Foundation
import Security
import SwiftUI
import UIKit
import UserNotifications
import WebKit

@objc(BangumiRootViewFactory)
public final class BangumiRootViewFactory: NSObject {
  private static let model = BangumiAppModel()

  @objc public static func makeRootViewController() -> UIViewController {
    let controller = UIHostingController(
      rootView: BangumiRootView()
        .environmentObject(model)
        .environmentObject(model.sessionStore)
        .environmentObject(model.settingsStore)
        .environmentObject(model.notificationStore)
    )
    controller.view.backgroundColor = .systemGroupedBackground
    return controller
  }
}

private enum BangumiTab: Hashable {
  case home
  case discovery
  case rakuen
  case me
}

private enum HomeCategory: String, CaseIterable, Identifiable {
  case all
  case anime
  case book
  case real
  case game

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: "全部"
    case .anime: "动画"
    case .book: "书籍"
    case .real: "三次元"
    case .game: "游戏"
    }
  }

  var subjectType: SubjectType? {
    switch self {
    case .all: nil
    case .anime: .anime
    case .book: .book
    case .real: .real
    case .game: .game
    }
  }
}

private enum PreferredTheme: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "跟随系统"
    case .light: "浅色"
    case .dark: "深色"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

private enum SubjectType: Int, CaseIterable, Identifiable {
  case book = 1
  case anime = 2
  case music = 3
  case game = 4
  case real = 6

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .book: "书籍"
    case .anime: "动画"
    case .music: "音乐"
    case .game: "游戏"
    case .real: "三次元"
    }
  }

  static func title(for rawValue: Int?) -> String {
    guard let rawValue, let type = SubjectType(rawValue: rawValue) else {
      return "条目"
    }
    return type.title
  }
}

private enum BangumiSearchMatchMode: String, CaseIterable, Identifiable {
  case precise
  case fuzzy

  var id: String { rawValue }

  var title: String {
    switch self {
    case .precise: "精准"
    case .fuzzy: "模糊"
    }
  }

  var isFuzzy: Bool {
    self == .fuzzy
  }
}

private struct BangumiSearchQuery: Hashable {
  let keyword: String
  let type: SubjectType
  let matchMode: BangumiSearchMatchMode
}

private enum CollectionStatus: String, CaseIterable, Identifiable {
  case wish
  case collect
  case doing = "do"
  case onHold = "on_hold"
  case dropped

  var id: String { rawValue }

  var title: String {
    switch self {
    case .wish: "想看"
    case .collect: "看过"
    case .doing: "在看"
    case .onHold: "搁置"
    case .dropped: "抛弃"
    }
  }

  var v0Type: String {
    switch self {
    case .wish: "1"
    case .collect: "2"
    case .doing: "3"
    case .onHold: "4"
    case .dropped: "5"
    }
  }
}

private enum TimelineFilter: String, CaseIterable, Identifiable {
  case all
  case say
  case subject
  case progress
  case group

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: "全部"
    case .say: "吐槽"
    case .subject: "收藏"
    case .progress: "进度"
    case .group: "小组"
    }
  }
}

private enum RakuenFilter: String, CaseIterable, Identifiable {
  case all = ""
  case group
  case subject
  case hot
  case ep
  case mono

  var id: String {
    if rawValue.isEmpty {
      return "all"
    }
    return rawValue
  }

  var title: String {
    switch self {
    case .all: "全部"
    case .group: "小组"
    case .subject: "条目"
    case .hot: "热门"
    case .ep: "章节"
    case .mono: "人物"
    }
  }
}

private struct BangumiToken: Codable {
  let accessToken: String
  let tokenType: String
  let expiresIn: Int
  let refreshToken: String?
  let userID: Int?

  var authorizationHeader: String {
    "\(tokenType) \(accessToken)"
  }
}

private struct BangumiUser: Codable, Identifiable {
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

private struct BangumiImages: Codable {
  let large: String?
  let common: String?
  let medium: String?
  let small: String?

  var best: URL? {
    BangumiRemoteURL.url(from: large ?? common ?? medium ?? small)
  }
}

private enum BangumiRemoteURL {
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

private struct BangumiRating: Codable {
  let score: Double?
  let rank: Int?
  let total: Int?
}

private struct BangumiTag: Codable, Hashable {
  let name: String
  let count: Int?
}

private struct BangumiSubjectSummary: Codable, Identifiable {
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

private struct BangumiSubject: Codable, Identifiable {
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

private struct BangumiSubjectCollectionStats: Codable {
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

private struct BangumiEpisode: Codable, Identifiable {
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

private enum BangumiEpisodeCollectionType: Int, Codable, CaseIterable, Hashable {
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

private struct BangumiEpisodeCollection: Identifiable, Hashable {
  let episodeID: Int
  let type: BangumiEpisodeCollectionType
  let updatedAt: Int?

  var id: Int { episodeID }
}

private enum BangumiNotificationPermissionState: String, Codable, CaseIterable, Identifiable {
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

private struct BangumiSubjectNotificationSubscription: Codable, Identifiable, Hashable {
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

private struct BangumiSubjectUpdateCheckResult {
  let subjectID: Int
  let hasUpdate: Bool
  let latestEpisode: BangumiEpisode?
  let checkedAt: Date
  let errorMessage: String?
}

private struct BangumiEpisodeCollectionsPageResponse: Codable {
  let total: Int?
  let data: [BangumiUserEpisodeCollectionDTO]
}

private struct BangumiUserEpisodeCollectionDTO: Codable {
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

private struct BangumiSubjectComment: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let userSign: String?
  let avatarURL: URL?
  let time: String
  let message: String
  let htmlMessage: String?
}

private struct BangumiSubjectPresentation: Hashable {
  let previews: [BangumiSubjectPreviewItem]
  let infoEntries: [BangumiSubjectInfoEntry]
  let ratingBreakdown: BangumiSubjectRatingBreakdown?
  let cast: [BangumiSubjectCastItem]
  let staff: [BangumiSubjectStaffItem]
  let relations: [BangumiSubjectRelationItem]
  let morePreviewsURL: URL?
  let moreCastURL: URL?
  let moreStaffURL: URL?
  let moreRelationsURL: URL?
  let statsURL: URL?

  static let empty = BangumiSubjectPresentation(
    previews: [],
    infoEntries: [],
    ratingBreakdown: nil,
    cast: [],
    staff: [],
    relations: [],
    morePreviewsURL: nil,
    moreCastURL: nil,
    moreStaffURL: nil,
    moreRelationsURL: nil,
    statsURL: nil
  )
}

private struct BangumiSubjectPreviewItem: Identifiable, Hashable {
  let id: String
  let title: String
  let caption: String?
  let imageURL: URL?
  let targetURL: URL?
}

private struct BangumiSubjectInfoEntry: Identifiable, Hashable {
  let id: String
  let label: String
  let textValue: String
  let htmlValue: String?
}

private struct BangumiSubjectRatingBreakdown: Hashable {
  let average: Double?
  let rank: Int?
  let totalVotes: Int?
  let buckets: [BangumiSubjectRatingBucket]
  let externalRatings: [BangumiSubjectExternalRating]
}

private struct BangumiSubjectRatingBucket: Identifiable, Hashable {
  let score: Int
  let count: Int

  var id: Int { score }
}

private struct BangumiSubjectExternalRating: Identifiable, Hashable {
  let source: String
  let scoreText: String
  let votesText: String?

  var id: String { source }
}

private struct BangumiSubjectCastItem: Identifiable, Hashable {
  let id: String
  let name: String
  let subtitle: String?
  let role: String?
  let actorName: String?
  let accentText: String?
  let imageURL: URL?
  let detailURL: URL?
}

private struct BangumiSubjectStaffItem: Identifiable, Hashable {
  let id: String
  let name: String
  let subtitle: String?
  let roles: String
  let credit: String?
  let accentText: String?
  let imageURL: URL?
  let detailURL: URL?
}

private struct BangumiSubjectRelationItem: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String?
  let relationLabel: String?
  let imageURL: URL?
  let detailURL: URL?
  let subjectID: Int?
}

private struct BangumiV0SubjectDTO: Codable {
  let id: Int
  let type: Int?
  let name: String
  let nameCN: String?
  let summary: String?
  let platform: String?
  let images: BangumiImages?
  let eps: Int?
  let totalEpisodes: Int?
  let volumes: Int?
  let date: String?
  let rating: BangumiRating?
  let tags: [BangumiTag]?
  let collection: BangumiSubjectCollectionStats?
  let locked: Bool?
  let nsfw: Bool?

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case name
    case nameCN = "name_cn"
    case summary
    case platform
    case images
    case eps
    case totalEpisodes = "total_episodes"
    case volumes
    case date
    case rating
    case tags
    case collection
    case locked
    case nsfw
  }

  func subject() -> BangumiSubject {
    BangumiSubject(
      id: id,
      type: type,
      name: name,
      nameCN: nameCN,
      summary: summary,
      images: images,
      eps: eps,
      totalEpisodes: totalEpisodes,
      volumes: volumes,
      platform: platform,
      date: date,
      rating: rating,
      tags: tags,
      locked: locked,
      nsfw: nsfw,
      collection: collection
    )
  }
}

private struct BangumiV0EpisodesResponse: Codable {
  let data: [BangumiV0EpisodeDTO]
}

private struct BangumiV0EpisodeDTO: Codable {
  let airdate: String?
  let comment: Int?
  let duration: String?
  let id: Int
  let name: String?
  let nameCN: String?
  let sort: Double?
  let type: Int?

  enum CodingKeys: String, CodingKey {
    case airdate
    case comment
    case duration
    case id
    case name
    case nameCN = "name_cn"
    case sort
    case type
  }

  func episode() -> BangumiEpisode {
    let hasDisplayTitle = !(name?.isEmpty ?? true) || !(nameCN?.isEmpty ?? true)
    return BangumiEpisode(
      id: id,
      name: name,
      nameCN: nameCN,
      sort: sort,
      airdate: airdate,
      status: hasDisplayTitle ? "Air" : "NA"
    )
  }
}

private struct BangumiCalendarDay: Codable, Identifiable {
  let weekday: BangumiWeekday
  let items: [BangumiSubjectSummary]

  var id: Int { weekday.id }
}

private struct BangumiWeekday: Codable {
  let id: Int
  let cn: String
}

private struct BangumiSubjectCollectionRecord: Codable {
  let type: String?
  let rate: Int?
  let comment: String?
  let epStatus: Int?
  let volStatus: Int?
  let tags: [String]?

  enum CodingKeys: String, CodingKey {
    case type
    case rate
    case comment
    case epStatus = "ep_status"
    case volStatus = "vol_status"
    case tags
  }
}

private struct BangumiCollectionsResponse: Codable {
  let total: Int?
  let data: [BangumiCollectionItem]
}

private struct BangumiImagePreview: Identifiable {
  let url: URL

  var id: String { url.absoluteString }
}

private enum BangumiModalRoute: Identifiable {
  case subject(Int)
  case user(String)
  case timeline(URL)
  case rakuen(URL)
  case web(URL, String)

  var id: String {
    switch self {
    case let .subject(id): "subject-\(id)"
    case let .user(id): "user-\(id)"
    case let .timeline(url): "timeline-\(url.absoluteString)"
    case let .rakuen(url): "rakuen-\(url.absoluteString)"
    case let .web(url, title): "web-\(title)-\(url.absoluteString)"
    }
  }
}

private struct BangumiCollectionItem: Codable, Identifiable {
  struct EmbeddedSubject: Codable {
    let id: Int?
    let type: Int?
    let name: String
    let nameCN: String?
    let date: String?
    let images: BangumiImages?
    let eps: Int?
    let totalEpisodes: Int?
    let rank: Int?
    let score: Double?

    enum CodingKeys: String, CodingKey {
      case id
      case type
      case name
      case nameCN = "name_cn"
      case date
      case images
      case eps
      case totalEpisodes = "total_episodes"
      case rank
      case score
    }
  }

  let subjectID: Int
  let subjectType: Int
  let epStatus: Int?
  let volStatus: Int?
  let updatedAt: String?
  let subject: EmbeddedSubject

  enum CodingKeys: String, CodingKey {
    case subjectID = "subject_id"
    case subjectType = "subject_type"
    case epStatus = "ep_status"
    case volStatus = "vol_status"
    case updatedAt = "updated_at"
    case subject
  }

  var id: Int { subjectID }
}

private struct SearchResponse: Codable {
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

private enum BangumiSubjectSearchWebParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectSummary] {
    guard let listHTML = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<ul id="browserItemList""#,
      end: "</ul>"
    ) else {
      return []
    }

    return BangumiHTMLParser.matches(
      in: listHTML,
      pattern: #"<li id="item_\d+" class="item.*?</li>"#
    ).compactMap { match -> BangumiSubjectSummary? in
      guard let block = BangumiHTMLParser.capture(listHTML, from: match, group: 0) else {
        return nil
      }

      let href = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="(/subject/\d+)" class="subjectCover"#
      )
      guard let id = BangumiHTMLParser.subjectID(from: href) else {
        return nil
      }

      let titleHTML = BangumiHTMLParser.firstCapture(in: block, pattern: #"<h3>(.*?)</h3>"#) ?? block
      let localizedTitle = BangumiHTMLParser.firstCapture(
        in: titleHTML,
        pattern: #"<a href="/subject/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !localizedTitle.isEmpty else { return nil }

      let originalTitle = BangumiHTMLParser.firstCapture(
        in: titleHTML,
        pattern: #"<small class="grey">(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags)
      let type = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"subject_type_(\d+)"#
      ).flatMap(Int.init)
      let cover = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<img src="([^"]+)""#
      )
      let rank = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"Rank </small>\s*(\d+)"#
      ).flatMap(Int.init)
      let meta = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<p class="info tip">\s*(.*?)\s*</p>"#
      ).map(BangumiHTMLParser.stripTags)
      let score = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="fade">([\d.]+)</small>"#
      ).flatMap(Double.init)
      let total = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"\((\d+)人评分\)"#
      ).flatMap(Int.init)
      let date = meta.flatMap(firstSearchDate(in:))
      let coverURL = BangumiHTMLParser.absoluteURL(from: cover, baseURL: baseURL)?.absoluteString

      return BangumiSubjectSummary(
        id: id,
        type: type,
        name: originalTitle ?? localizedTitle,
        nameCN: localizedTitle,
        images: BangumiImages(
          large: coverURL,
          common: coverURL,
          medium: coverURL,
          small: coverURL
        ),
        eps: nil,
        totalEpisodes: nil,
        date: date,
        rating: BangumiRating(
          score: score,
          rank: rank,
          total: total
        ),
        searchMeta: meta
      )
    }
  }

  private static func firstSearchDate(in text: String) -> String? {
    guard
      let match = BangumiHTMLParser.matches(
        in: text,
        pattern: #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
      ).first,
      let year = BangumiHTMLParser.capture(text, from: match, group: 1),
      let month = BangumiHTMLParser.capture(text, from: match, group: 2).flatMap(Int.init),
      let day = BangumiHTMLParser.capture(text, from: match, group: 3).flatMap(Int.init)
    else {
      return nil
    }

    return String(format: "%@-%02d-%02d", year, month, day)
  }
}

private struct OAuthTokenDTO: Codable {
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

private struct EmptyResponse: Codable {}

private struct CollectionUpdatePayload {
  var status: CollectionStatus
  var rating: Int
  var tags: String
  var comment: String
  var isPrivate: Bool
  var watchedEpisodes: Int?
  var watchedVolumes: Int?
}

private struct BangumiTimelinePage {
  let items: [BangumiTimelineItem]
  let nextPage: Int?
}

private struct BangumiTimelineItem: Identifiable, Hashable {
  let id: String
  let date: String
  let time: String
  let summary: String
  let actorName: String
  let actorURL: URL?
  let targetTitle: String?
  let targetURL: URL?
  let subjectID: Int?
  let avatarURL: URL?
  let imageURLs: [URL]
  let comment: String?
  let replyCount: String?
  let replyURL: URL?

  var navigationURL: URL? {
    replyURL ?? targetURL ?? actorURL
  }
}

private struct BangumiTimelineDetail {
  let main: BangumiTimelinePost
  let replies: [BangumiTimelinePost]
}

private struct BangumiTimelinePost: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let avatarURL: URL?
  let date: String
  let text: String
  let htmlText: String?
}

private struct BangumiUserProfile: Identifiable, Hashable {
  let username: String
  let displayName: String
  let avatarURL: URL?
  let sign: String?
  let bio: String?
  let joinedAt: String?
  let location: String?

  var id: String { username }
}

private struct BangumiRakuenSubReply: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let userSign: String?
  let avatarURL: URL?
  let floor: String?
  let time: String
  let message: String
  let htmlMessage: String?
}

private struct BangumiRakuenItem: Identifiable, Hashable {
  let id: String
  let title: String
  let topicURL: URL?
  let userName: String
  let userID: String?
  let avatarURL: URL?
  let groupName: String?
  let groupURL: URL?
  let replyCount: String?
  let time: String
}

private struct BangumiRakuenTopicDetail {
  let topic: BangumiRakuenTopic
  let comments: [BangumiRakuenComment]
}

private struct BangumiRakuenTopic: Hashable {
  let id: String
  let title: String
  let groupName: String?
  let groupURL: URL?
  let userName: String
  let userID: String?
  let userSign: String?
  let avatarURL: URL?
  let floor: String?
  let time: String
  let message: String
  let htmlMessage: String?
}

private struct BangumiRakuenComment: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let userSign: String?
  let avatarURL: URL?
  let floor: String?
  let time: String
  let message: String
  let htmlMessage: String?
  let subReplies: [BangumiRakuenSubReply]
}

private enum BangumiDesign {
  static let screenHorizontalPadding: CGFloat = 16
  static let rowSpacing: CGFloat = 12
  static let sectionSpacing: CGFloat = 8
  static let cardPadding: CGFloat = 12
  static let cardRadius: CGFloat = 18
  static let heroRadius: CGFloat = 28
  static let rootTabBarClearance: CGFloat = 96
}

private enum BangumiTypography {
  static let miSansRegular = "MiSans-Regular"
  static let miSansMedium = "MiSans-Medium"
  static let miSansBold = "MiSans-Bold"
  static let detailLinkUIColor = UIColor(red: 0.92, green: 0.42, blue: 0.60, alpha: 1)
  static let detailLinkColor = Color(uiColor: detailLinkUIColor)

  static func detailFont(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
    switch weight {
    case .bold, .heavy, .black:
      return .custom(miSansBold, size: size)
    case .medium, .semibold:
      return .custom(miSansMedium, size: size)
    default:
      return .custom(miSansRegular, size: size)
    }
  }

  static func detailUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    let name: String
    switch weight {
    case .bold, .heavy, .black:
      name = miSansBold
    case .medium, .semibold:
      name = miSansMedium
    default:
      name = miSansRegular
    }

    return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
  }
}

private enum BangumiDiscoveryDesign {
  static let screenSpacing: CGFloat = 22
  static let cardSpacing: CGFloat = 14
  static let heroPageInset: CGFloat = BangumiDesign.screenHorizontalPadding
  static let heroHeight: CGFloat = 510
  static let heroRadius: CGFloat = 32
  static let sectionRadius: CGFloat = 30
  static let rowRadius: CGFloat = 24
  static let sectionPadding: CGFloat = 18
  static let rowPadding: CGFloat = 14
  static let rowCoverWidth: CGFloat = 74
  static let rowCoverHeight: CGFloat = 98
}

private enum BangumiDiscoveryCopy {
  static let eyebrow = "DISCOVER"
  static let title = "发现"
  static let summary = "把一周放送表排成更像刊物首页的卡片流。"
  static let heroEyebrow = "SPOTLIGHT"
  static let heroTitle = "今日主打"
  static let sectionEyebrow = "SWIMLANE"
  static let sectionSummary = "按星期整理的放送清单，保留时间线但强化卡片层级。"
}

private enum BangumiSearchDesign {
  static let barHeight: CGFloat = 56
  static let searchRadius: CGFloat = 28
  static let panelRadius: CGFloat = 26
  static let panelPadding: CGFloat = 18
  static let resultRadius: CGFloat = 28
  static let resultCoverWidth: CGFloat = 76
  static let resultCoverHeight: CGFloat = 100
}

private struct BangumiHTMLAnchor {
  let href: String
  let text: String
  let title: String?
}

private enum BangumiHTMLParser {
  static func extractSection(in html: String, start: String, end: String) -> String? {
    guard let startRange = html.range(of: start) else { return nil }
    let remaining = html[startRange.upperBound...]
    guard let endRange = remaining.range(of: end) else { return nil }
    return String(remaining[..<endRange.lowerBound])
  }

  static func matches(in text: String, pattern: String) -> [NSTextCheckingResult] {
    guard let regex = try? NSRegularExpression(
      pattern: pattern,
      options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
      return []
    }

    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, options: [], range: range)
  }

  static func firstCapture(in text: String, pattern: String, group: Int = 1) -> String? {
    matches(in: text, pattern: pattern).first.flatMap { capture(text, from: $0, group: group) }
  }

  static func capture(_ text: String, from result: NSTextCheckingResult, group: Int) -> String? {
    guard group < result.numberOfRanges else { return nil }
    let range = result.range(at: group)
    guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
    return String(text[swiftRange])
  }

  static func splitBlocks(in text: String, marker: String) -> [String] {
    let parts = text.components(separatedBy: marker)
    guard parts.count > 1 else { return [] }

    return parts.dropFirst().map { marker + $0 }
  }

  static func stripTags(_ html: String) -> String {
    let withoutBreaks = html
      .replacingOccurrences(of: "<br ?/?>", with: "\n", options: .regularExpression)
      .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
      .replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
      .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    return decodeEntities(withoutBreaks)
  }

  static func decodeEntities(_ text: String) -> String {
    let data = Data(text.utf8)
    if let attributed = try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) {
      return collapseWhitespace(attributed.string)
    }

    let replacements = [
      "&nbsp;": " ",
      "&amp;": "&",
      "&quot;": "\"",
      "&#039;": "'",
      "&lt;": "<",
      "&gt;": ">"
    ]

    let normalized = replacements.reduce(text) { partialResult, pair in
      partialResult.replacingOccurrences(of: pair.key, with: pair.value)
    }
    return collapseWhitespace(normalized)
  }

  static func attributedString(from html: String, baseURL: URL) -> AttributedString? {
    let webPrefix = baseURL.absoluteString + "/"
    let normalizedHTML = mediaStrippedHTML(from: html)
      .replacingOccurrences(of: "href=\"/", with: "href=\"\(webPrefix)")
      .replacingOccurrences(of: "src=\"/", with: "src=\"\(webPrefix)")
    let wrappedHTML = """
    <html>
      <head>
        <meta charset="utf-8">
      </head>
      <body>\(normalizedHTML)</body>
    </html>
    """

    guard let data = wrappedHTML.data(using: .utf8) else { return nil }
    guard let attributed = try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) else {
      return nil
    }

    guard let swiftAttributed = try? AttributedString(attributed, including: \.uiKit) else {
      return nil
    }
    return swiftAttributed
  }

  static func mediaStrippedHTML(from html: String) -> String {
    html
      .replacingOccurrences(of: #"<img[^>]*>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"<blockquote[^>]*>.*?</blockquote>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"<div class="quote"[^>]*>.*?</div>"#, with: "", options: .regularExpression)
  }

  static func imageURLs(in html: String, baseURL: URL) -> [URL] {
    matches(in: html, pattern: #"<img[^>]*src="([^"]+)""#).compactMap { match in
      absoluteURL(from: capture(html, from: match, group: 1), baseURL: baseURL)
    }
  }

  static func quoteBlocks(in html: String) -> [String] {
    let blockquotes = matches(
      in: html,
      pattern: #"<blockquote[^>]*>(.*?)</blockquote>"#
    ).compactMap { match in
      capture(html, from: match, group: 1).map(stripTags)
    }

    let quoteDivs = matches(
      in: html,
      pattern: #"<div class="quote"[^>]*>(.*?)</div>"#
    ).compactMap { match in
      capture(html, from: match, group: 1).map(stripTags)
    }

    return Array(Set((blockquotes + quoteDivs).filter { !$0.isEmpty }))
  }

  static func collapseWhitespace(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "[\\t\\f\\v ]+", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\n\\s*\\n+", with: "\n", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func parseAvatarURL(from style: String, baseURL: URL) -> URL? {
    guard let value = firstCapture(
      in: style,
      pattern: #"url\((?:'|")?(.+?)(?:'|")?\)"#
    ) else {
      return nil
    }

    return absoluteURL(from: value, baseURL: baseURL)
  }

  static func parseAvatarURLFromHTML(_ html: String, baseURL: URL) -> URL? {
    let stylePatterns = [
      #"<(?:span|div|a)[^>]*class="[^"]*avatar[^"]*"[^>]*style="([^"]+)""#,
      #"<(?:span|div|a)[^>]*class='[^']*avatar[^']*'[^>]*style='([^']+)'"#,
      #"<(?:span|div|a)[^>]*style="([^"]*background-image\s*:\s*url\([^)]+\)[^"]*)""#,
      #"<(?:span|div|a)[^>]*style='([^']*background-image\s*:\s*url\([^)]+\)[^']*)'"#
    ]

    for pattern in stylePatterns {
      if let style = firstCapture(in: html, pattern: pattern),
         let url = parseAvatarURL(from: style, baseURL: baseURL) {
        return url
      }
    }

    let sourcePatterns = [
      #"<img[^>]*class="[^"]*avatar[^"]*"[^>]*src="([^"]+)""#,
      #"<img[^>]*class='[^']*avatar[^']*'[^>]*src='([^']+)'"#,
      #"<img[^>]*src="([^"]+)""#,
      #"<img[^>]*src='([^']+)'"#,
      #"<img[^>]*data-src="([^"]+)""#,
      #"<img[^>]*data-src='([^']+)'"#
    ]

    for pattern in sourcePatterns {
      if let source = firstCapture(in: html, pattern: pattern),
         let url = absoluteURL(from: source, baseURL: baseURL) {
        return url
      }
    }

    return nil
  }

  static func absoluteURL(from href: String?, baseURL: URL) -> URL? {
    guard let href, !href.isEmpty else { return nil }
    if let normalized = BangumiRemoteURL.url(from: href), normalized.scheme != nil {
      return normalized
    }
    if let url = URL(string: href), url.scheme != nil {
      return url
    }
    return URL(string: href, relativeTo: baseURL)?.absoluteURL
  }

  static func subjectID(from href: String?) -> Int? {
    guard let href else { return nil }
    guard let value = firstCapture(in: href, pattern: #"/subject/(\d+)"#) else { return nil }
    return Int(value)
  }

  static func anchors(in html: String) -> [BangumiHTMLAnchor] {
    matches(
      in: html,
      pattern: #"<a\b([^>]*?)href="([^"]+)"([^>]*)>(.*?)</a>"#
    ).compactMap { match in
      guard
        let beforeAttributes = capture(html, from: match, group: 1),
        let href = capture(html, from: match, group: 2),
        let afterAttributes = capture(html, from: match, group: 3),
        let innerHTML = capture(html, from: match, group: 4)
      else {
        return nil
      }

      let titleSource = beforeAttributes + afterAttributes
      let title = firstCapture(in: titleSource, pattern: #"title="([^"]+)""#)
      return BangumiHTMLAnchor(
        href: href,
        text: stripTags(innerHTML),
        title: title.map(decodeEntities)
      )
    }
  }
}

private enum BangumiSubjectWebParser {
  static func parse(html: String, id: Int, baseURL: URL) -> BangumiSubject {
    let titleHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<h1[^>]*class="nameSingle"[^>]*>(.*?)</h1>"#
    ) ?? ""
    let chineseName = BangumiHTMLParser.firstCapture(
      in: titleHTML,
      pattern: #"<a[^>]*title="([^"]+)""#
    ).map(BangumiHTMLParser.decodeEntities)
    let primaryName = BangumiHTMLParser.firstCapture(
      in: titleHTML,
      pattern: #"<a[^>]*>(.*?)</a>"#
    ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 条目"

    let summaryHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="subject_summary"[^>]*>(.*?)</div>"#
    ) ?? ""
    let summary = BangumiHTMLParser.stripTags(summaryHTML)

    let coverURL = BangumiHTMLParser.absoluteURL(
      from: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<img[^>]*class="cover"[^>]*src="([^"]+)""#
      ),
      baseURL: baseURL
    )?.absoluteString

    let score = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="number">([\d.]+)</span>"#
    ).flatMap(Double.init)
    let rank = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"排名[^#]*#(\d+)"#
    ).flatMap(Int.init)
    let total = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="tip_j">\((\d+)\)</span>"#
    ).flatMap(Int.init)

    let infoboxHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<ul id="infobox">(.*?)</ul>"#
    ) ?? ""
    let eps = metadataValue(in: infoboxHTML, labels: ["话数", "集数"]).flatMap(Int.init)
    let totalEpisodes = eps
    let volumes = metadataValue(in: infoboxHTML, labels: ["卷数"]).flatMap(Int.init)
    let platform = metadataValue(in: infoboxHTML, labels: ["平台"])
    let date = metadataValue(in: infoboxHTML, labels: ["放送开始", "发售日", "上映年度", "开始", "日期"])

    let tags: [BangumiTag] = BangumiHTMLParser.matches(
      in: html,
      pattern: #"<a[^>]*class="l[^"]*"[^>]*><span>(.*?)</span><small>(.*?)</small></a>"#
    ).compactMap { match in
      guard
        let name = BangumiHTMLParser.capture(html, from: match, group: 1).map(BangumiHTMLParser.stripTags),
        !name.isEmpty
      else {
        return nil
      }

      let count = BangumiHTMLParser.capture(html, from: match, group: 2)
        .map(BangumiHTMLParser.stripTags)
        .flatMap(Int.init)
      return BangumiTag(name: name, count: count)
    }

    return BangumiSubject(
      id: id,
      type: metadataSubjectType(in: html),
      name: primaryName,
      nameCN: chineseName,
      summary: summary.isEmpty ? nil : summary,
      images: BangumiImages(large: coverURL, common: coverURL, medium: coverURL, small: coverURL),
      eps: eps,
      totalEpisodes: totalEpisodes,
      volumes: volumes,
      platform: platform,
      date: date,
      rating: BangumiRating(score: score, rank: rank, total: total),
      tags: tags.isEmpty ? nil : tags,
      locked: nil,
      nsfw: nil,
      collection: nil
    )
  }

  static func parseEpisodes(html: String) -> [BangumiEpisode] {
    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<li class="episode"#)
    return blocks.compactMap { block in
      guard let id = BangumiHTMLParser.firstCapture(in: block, pattern: #"data-ep-id="(\d+)""#).flatMap(Int.init) ??
        BangumiHTMLParser.firstCapture(in: block, pattern: #"/ep/(\d+)"#).flatMap(Int.init) else {
        return nil
      }

      let sort = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="epAirStatus[^"]*">\s*EP\.?(\d+(?:\.\d+)?)"#
      ).flatMap(Double.init) ?? BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small[^>]*>(\d+(?:\.\d+)?)</small>"#
      ).flatMap(Double.init)

      let nameCN = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="l ep_status"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags)
      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="tip"[^>]*>(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let airdate = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="tip_j">\((.*?)\)</span>"#
      ).map(BangumiHTMLParser.stripTags)

      return BangumiEpisode(
        id: id,
        name: name,
        nameCN: nameCN,
        sort: sort,
        airdate: airdate,
        status: (nameCN?.isEmpty == false || name?.isEmpty == false) ? "Air" : "NA"
      )
    }
    .sorted { lhs, rhs in
      (lhs.sort ?? .greatestFiniteMagnitude) < (rhs.sort ?? .greatestFiniteMagnitude)
    }
  }

  private static func metadataValue(in infoboxHTML: String, labels: [String]) -> String? {
    for label in labels {
      let escapedLabel = NSRegularExpression.escapedPattern(for: label)
      let pattern = "<li>\\s*<span>\(escapedLabel):\\s*</span>(.*?)</li>"
      if let value = BangumiHTMLParser.firstCapture(
        in: infoboxHTML,
        pattern: pattern
      ) {
        let normalized = BangumiHTMLParser.stripTags(value)
        if !normalized.isEmpty {
          return normalized
        }
      }
    }
    return nil
  }

  private static func metadataSubjectType(in html: String) -> Int? {
    let typeText = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<small class="grey">(.*?)</small>"#
    ).map(BangumiHTMLParser.stripTags) ?? ""

    if typeText.contains("书籍") {
      return SubjectType.book.rawValue
    }
    if typeText.contains("动画") {
      return SubjectType.anime.rawValue
    }
    if typeText.contains("音乐") {
      return SubjectType.music.rawValue
    }
    if typeText.contains("游戏") {
      return SubjectType.game.rawValue
    }
    if typeText.contains("三次元") {
      return SubjectType.real.rawValue
    }
    return nil
  }
}

private enum BangumiSubjectCommentsParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectComment] {
    let commentBox =
      BangumiHTMLParser.extractSection(
        in: html,
        start: #"<div id="comment_box""#,
        end: #"<template id="likes_reaction_grid_item""#
      ) ??
      BangumiHTMLParser.extractSection(
        in: html,
        start: #"<div id="comment_box""#,
        end: #"<div id="footer">"#
      ) ??
      ""

    let blocks = BangumiHTMLParser.splitBlocks(in: commentBox, marker: #"<div class="item clearit""#)
    return blocks.compactMap { block in
      let messageHTML = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<p class="comment">(.*?)</p>"#
      ) ?? ""
      let message = BangumiHTMLParser.stripTags(messageHTML)

      guard !message.isEmpty else { return nil }

      let greyTexts = BangumiHTMLParser.matches(
        in: block,
        pattern: #"<small[^>]*class="grey"[^>]*>(.*?)</small>"#
      )
      .compactMap { BangumiHTMLParser.capture(block, from: $0, group: 1) }
      .map(BangumiHTMLParser.stripTags)
      .filter { !$0.isEmpty }

      let userSign = greyTexts.first { !$0.contains("@") }
      let time = greyTexts.first { $0.contains("@") }?
        .replacingOccurrences(of: "@", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      let userID = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*href="/user/([^"/]+)""#
      )
      let userName = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="l"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户"

      let avatarURL = BangumiHTMLParser.parseAvatarURLFromHTML(block, baseURL: baseURL)

      let identity = userID ?? BangumiHTMLParser.collapseWhitespace(userName)
      let identifier = [identity, time, message]
        .joined(separator: "|")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return BangumiSubjectComment(
        id: identifier.isEmpty ? UUID().uuidString : identifier,
        userName: userName,
        userID: userID,
        userSign: userSign,
        avatarURL: avatarURL,
        time: time,
        message: message,
        htmlMessage: messageHTML.isEmpty ? nil : messageHTML
      )
    }
  }
}

private enum BangumiSubjectPresentationParser {
  static func parse(
    subjectHTML: String,
    charactersHTML: String?,
    staffHTML: String?,
    relationsHTML: String?,
    subjectID: Int,
    baseURL: URL
  ) -> BangumiSubjectPresentation {
    let infoEntries = parseInfoEntries(html: subjectHTML)
    let parsedStaff = parseStaff(html: staffHTML, baseURL: baseURL)

    return BangumiSubjectPresentation(
      previews: parsePreviews(html: subjectHTML, baseURL: baseURL),
      infoEntries: infoEntries,
      ratingBreakdown: parseRatingBreakdown(html: subjectHTML),
      cast: parseCast(html: charactersHTML, baseURL: baseURL),
      staff: parsedStaff.isEmpty ? parseStaffFallback(from: infoEntries, baseURL: baseURL) : parsedStaff,
      relations: parseRelations(html: relationsHTML, baseURL: baseURL),
      morePreviewsURL: nil,
      moreCastURL: URL(string: "/subject/\(subjectID)/characters", relativeTo: baseURL)?.absoluteURL,
      moreStaffURL: URL(string: "/subject/\(subjectID)/persons?group=person", relativeTo: baseURL)?.absoluteURL,
      moreRelationsURL: URL(string: "/subject/\(subjectID)/relations", relativeTo: baseURL)?.absoluteURL,
      statsURL: URL(string: "/subject/\(subjectID)/stats", relativeTo: baseURL)?.absoluteURL
    )
  }

  private static func parsePreviews(html: String, baseURL: URL) -> [BangumiSubjectPreviewItem] {
    let candidateTitles = ["预览", "图集", "截图", "相册", "剧照"]
    for title in candidateTitles {
      if let section = BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<h2 class="subtitle">\#(title)</h2>(.*?)(?=<h2 class="subtitle"|<div id="footer">)"#
      ) {
        let items = BangumiHTMLParser.matches(
          in: section,
          pattern: #"<a[^>]*href="([^"]+)"[^>]*>(?:<span[^>]*style="[^"]*url\(([^)]+)\)[^"]*"[^>]*>|<img[^>]*src="([^"]+)")[\s\S]*?</a>"#
        ).compactMap { match -> BangumiSubjectPreviewItem? in
          let href = BangumiHTMLParser.capture(section, from: match, group: 1)
          let imageSource = BangumiHTMLParser.capture(section, from: match, group: 2) ??
            BangumiHTMLParser.capture(section, from: match, group: 3)
          let title = BangumiHTMLParser.decodeEntities(
            BangumiHTMLParser.firstCapture(
              in: BangumiHTMLParser.capture(section, from: match, group: 0) ?? "",
              pattern: #"title="([^"]+)""#
            ) ?? ""
          )
          let url = BangumiHTMLParser.absoluteURL(from: href, baseURL: baseURL)
          let imageURL = BangumiHTMLParser.absoluteURL(
            from: imageSource?.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: ""),
            baseURL: baseURL
          )
          guard url != nil || imageURL != nil else { return nil }
          return BangumiSubjectPreviewItem(
            id: href ?? UUID().uuidString,
            title: title.isEmpty ? "图集" : title,
            caption: nil,
            imageURL: imageURL,
            targetURL: url
          )
        }
        if !items.isEmpty {
          return Array(items.prefix(8))
        }
      }
    }

    return []
  }

  private static func parseInfoEntries(html: String) -> [BangumiSubjectInfoEntry] {
    guard let infoboxHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<ul id="infobox">(.*?)</ul>"#
    ) else {
      return []
    }

    return BangumiHTMLParser.matches(
      in: infoboxHTML,
      pattern: #"<li[^>]*>\s*<span class="tip">(.*?)</span>\s*(.*?)</li>"#
    ).compactMap { match in
      let label = BangumiHTMLParser.capture(infoboxHTML, from: match, group: 1)
        .map(BangumiHTMLParser.stripTags)?
        .replacingOccurrences(of: "：", with: "")
        .replacingOccurrences(of: ":", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let valueHTML = BangumiHTMLParser.capture(infoboxHTML, from: match, group: 2)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let valueText = valueHTML.map(BangumiHTMLParser.stripTags) ?? ""
      guard !label.isEmpty, !valueText.isEmpty else { return nil }
      return BangumiSubjectInfoEntry(
        id: "\(label)|\(valueText.prefix(24))",
        label: label,
        textValue: valueText,
        htmlValue: valueHTML
      )
    }
  }

  private static func parseRatingBreakdown(html: String) -> BangumiSubjectRatingBreakdown? {
    let average = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="number"[^>]*>([\d.]+)</span>"#
    ).flatMap(Double.init)
    let rank = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"Bangumi [A-Za-z]+ Ranked:</small><small class="alarm">#(\d+)"#
    ).flatMap(Int.init) ?? BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"排名[^#]*#(\d+)"#
    ).flatMap(Int.init)
    let totalVotes = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span property="v:votes">(\d+)</span>"#
    ).flatMap(Int.init)

    let buckets = BangumiHTMLParser.matches(
      in: html,
      pattern: #"<li><a[^>]*title="[^"]*"[^>]*><span class="label">(\d+)</span><span class="count"[^>]*>\((\d+)\)</span></a></li>"#
    ).compactMap { match -> BangumiSubjectRatingBucket? in
      guard
        let score = BangumiHTMLParser.capture(html, from: match, group: 1).flatMap(Int.init),
        let count = BangumiHTMLParser.capture(html, from: match, group: 2).flatMap(Int.init)
      else {
        return nil
      }
      return BangumiSubjectRatingBucket(score: score, count: count)
    }
    .sorted { $0.score > $1.score }

    let externalRatings = BangumiHTMLParser.matches(
      in: html,
      pattern: #"([A-Za-z][A-Za-z0-9]+):\s*([\d.]+)(?:\s*\((\d+)\))?"#
    ).compactMap { match -> BangumiSubjectExternalRating? in
      let source = BangumiHTMLParser.capture(html, from: match, group: 1) ?? ""
      guard ["VIB", "AniDB", "MAL", "IMDb", "Douban"].contains(source) else { return nil }
      let scoreText = BangumiHTMLParser.capture(html, from: match, group: 2) ?? ""
      let votes = BangumiHTMLParser.capture(html, from: match, group: 3)
      return BangumiSubjectExternalRating(
        source: source,
        scoreText: scoreText,
        votesText: votes
      )
    }

    guard average != nil || totalVotes != nil || !buckets.isEmpty else { return nil }
    return BangumiSubjectRatingBreakdown(
      average: average,
      rank: rank,
      totalVotes: totalVotes,
      buckets: buckets,
      externalRatings: externalRatings
    )
  }

  private static func parseCast(html: String?, baseURL: URL) -> [BangumiSubjectCastItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<a name="id_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/character/\d+)""#) else {
        return nil
      }

      let detailURL = BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL)
      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<a href="/character/\d+" class="avatar"><img src="([^"]+)""#
        ),
        baseURL: baseURL
      )

      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/character/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !name.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle">.*?<span class="tip">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let role = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="badge_job_tip badge_job"[^>]*>(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let actorName = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<div class="actorBadge.*?<p><a href="/person/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags)
      let accentText = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="primary">\((\+\d+)\)</small>"#
      )

      return BangumiSubjectCastItem(
        id: detailHref,
        name: name,
        subtitle: subtitle,
        role: role,
        actorName: actorName,
        accentText: accentText,
        imageURL: imageURL,
        detailURL: detailURL
      )
    }
    .prefix(12)
    .map { $0 }
  }

  private static func parseStaff(html: String?, baseURL: URL) -> [BangumiSubjectStaffItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<a name="id_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/person/\d+)""#) else {
        return nil
      }

      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/person/\d+">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !name.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/person/\d+">.*?<span class="tip">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)

      let roles = BangumiHTMLParser.matches(
        in: block,
        pattern: #"<span class="badge_job">(.*?)</span>"#
      )
      .compactMap { BangumiHTMLParser.capture(block, from: $0, group: 1).map(BangumiHTMLParser.stripTags) }
      .filter { !$0.isEmpty }
      .joined(separator: " · ")

      let credit = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<div class="prsn_info">\s*<span class="tip">\s*(.*?)</span>\s*</div>"#
      ).map(BangumiHTMLParser.stripTags)

      let accentText = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="orange">\((\+\d+)\)</small>"#
      )

      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<(?:a href="/person/\d+" class="avatar"><img|img)[^>]*src="([^"]+)""#
        ),
        baseURL: baseURL
      )

      return BangumiSubjectStaffItem(
        id: detailHref,
        name: name,
        subtitle: subtitle,
        roles: roles.isEmpty ? "制作人员" : roles,
        credit: credit,
        accentText: accentText,
        imageURL: imageURL,
        detailURL: BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL)
      )
    }
    .prefix(12)
    .map { $0 }
  }

  private static func parseStaffFallback(
    from entries: [BangumiSubjectInfoEntry],
    baseURL: URL
  ) -> [BangumiSubjectStaffItem] {
    var seen = Set<String>()
    var items: [BangumiSubjectStaffItem] = []

    for entry in entries {
      let anchors = BangumiHTMLParser.anchors(in: entry.htmlValue ?? "")
        .filter { $0.href.contains("/person/") }

      guard !anchors.isEmpty else { continue }

      for anchor in anchors {
        let normalizedName = BangumiHTMLParser.collapseWhitespace(anchor.text)
        guard !normalizedName.isEmpty else { continue }

        let id = "\(entry.label)|\(anchor.href)"
        guard !seen.contains(id) else { continue }
        seen.insert(id)

        let subtitle = anchor.title
          .map(BangumiHTMLParser.collapseWhitespace)
          .flatMap { title in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == normalizedName ? nil : trimmed
          }

        items.append(
          BangumiSubjectStaffItem(
            id: id,
            name: normalizedName,
            subtitle: subtitle,
            roles: entry.label,
            credit: nil,
            accentText: nil,
            imageURL: nil,
            detailURL: BangumiHTMLParser.absoluteURL(from: anchor.href, baseURL: baseURL)
          )
        )
      }
    }

    return Array(items.prefix(12))
  }

  private static func parseRelations(html: String?, baseURL: URL) -> [BangumiSubjectRelationItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<li id="item_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/subject/\d+)""#) else {
        return nil
      }

      let title = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="/subject/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="/subject/\d+" class="title">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !title.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="grey">(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags)
      let relationLabel = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="sub">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<img src="([^"]+)""#
        ) ?? BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"background-image:url\((?:'|")?(.+?)(?:'|")?\)"#
        ),
        baseURL: baseURL
      )

      return BangumiSubjectRelationItem(
        id: detailHref,
        title: title,
        subtitle: subtitle,
        relationLabel: relationLabel?.isEmpty == true ? nil : relationLabel,
        imageURL: imageURL,
        detailURL: BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL),
        subjectID: BangumiHTMLParser.subjectID(from: detailHref)
      )
    }
    .prefix(12)
    .map { $0 }
  }
}

private enum BangumiTimelineParser {
  static func parse(html: String, page: Int, baseURL: URL) -> BangumiTimelinePage {
    let content = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<div id="timeline">"#,
      end: #"<div id="tmlPager">"#
    ) ?? html

    var items: [BangumiTimelineItem] = []
    let sections = BangumiHTMLParser.matches(
      in: content,
      pattern: #"<h4[^>]*>(.*?)</h4>(.*?)(?=<h4|$)"#
    )

    for section in sections {
      let date = BangumiHTMLParser.decodeEntities(
        BangumiHTMLParser.capture(content, from: section, group: 1) ?? ""
      )
      let body = BangumiHTMLParser.capture(content, from: section, group: 2) ?? ""

      for block in BangumiHTMLParser.splitBlocks(in: body, marker: #"<li id="tml_"#) {
        let itemID = BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<li id="tml_([^"]+)""#
        ) ?? UUID().uuidString
        let infoHTML = BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<span class="info(?:_full)?">(.*?)</span>"#
        ) ?? ""
        let anchors = BangumiHTMLParser.anchors(in: infoHTML)
        let actor = anchors.first
        let target = anchors.first(where: { $0.href.contains("/subject/") }) ??
          anchors.dropFirst().first
        let summary = BangumiHTMLParser.stripTags(infoHTML)
        let comment = BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<div class="comment[^"]*">(.*?)</div>"#
        ).map(BangumiHTMLParser.stripTags)
        let time = BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<span class="titleTip(?:\s+tip_j)?">(.*?)</span>"#
        ).map(BangumiHTMLParser.stripTags) ?? ""
        let replyText = BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<a[^>]*class="tml_comment"[^>]*>(.*?)</a>"#
        ).map(BangumiHTMLParser.stripTags)
        let replyURL = BangumiHTMLParser.absoluteURL(
          from: BangumiHTMLParser.firstCapture(
            in: block,
            pattern: #"<a[^>]*class="tml_comment"[^>]*href="([^"]+)""#
          ),
          baseURL: baseURL
        )
        let avatarURL = BangumiHTMLParser.parseAvatarURL(
          from: BangumiHTMLParser.firstCapture(
            in: block,
            pattern: #"<span class="avatarNeue"[^>]*style="([^"]+)""#
          ) ?? "",
          baseURL: baseURL
        )
        let imageURLs = BangumiHTMLParser.matches(
          in: block,
          pattern: #"<img[^>]*src="([^"]+)""#
        ).compactMap { match in
          BangumiHTMLParser.absoluteURL(
            from: BangumiHTMLParser.capture(block, from: match, group: 1),
            baseURL: baseURL
          )
        }

        items.append(
          BangumiTimelineItem(
            id: "\(page)|\(itemID)",
            date: date,
            time: time,
            summary: summary,
            actorName: actor?.text ?? "",
            actorURL: BangumiHTMLParser.absoluteURL(from: actor?.href, baseURL: baseURL),
            targetTitle: target?.text.isEmpty == false ? target?.text : nil,
            targetURL: BangumiHTMLParser.absoluteURL(from: target?.href, baseURL: baseURL),
            subjectID: BangumiHTMLParser.subjectID(from: target?.href),
            avatarURL: avatarURL,
            imageURLs: Array(imageURLs.prefix(3)),
            comment: comment?.isEmpty == true ? nil : comment,
            replyCount: replyText?.isEmpty == true ? nil : replyText,
            replyURL: replyURL
          )
        )
      }
    }

    return BangumiTimelinePage(
      items: items,
      nextPage: items.isEmpty ? nil : page + 1
    )
  }
}

private enum BangumiTimelineDetailParser {
  static func parse(html: String, baseURL: URL) -> BangumiTimelineDetail {
    let content = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<div class="columnsApp""#,
      end: #"<div id="footer">"#
    ) ?? html

    let mainID = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<div class="statusHeader".*?<p class="tip">(.*?)</p>"#
    ).map(BangumiHTMLParser.stripTags)?
      .replacingOccurrences(of: "@", with: "") ?? UUID().uuidString
    let avatarURL = BangumiHTMLParser.absoluteURL(
      from: BangumiHTMLParser.firstCapture(
        in: content,
        pattern: #"<img[^>]*class="avatar"[^>]*src="([^"]+)""#
      ),
      baseURL: baseURL
    )
    let userName = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<div class="statusHeader".*?<h3>\s*<a[^>]*>(.*?)</a>"#
    ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户"
    let userID = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<div class="statusHeader".*?<h3>\s*<a[^>]*href="/user/([^"/]+)""#
    )
    let mainHTML = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<div class="statusContent".*?<p class="text">(.*?)</p>"#
    ) ?? BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<div class="sub_info".*?<div class="comment">(.*?)</div>"#
    ) ?? ""
    let mainText = BangumiHTMLParser.stripTags(mainHTML)
    let date = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<p class="date[^"]*">(.*?)</p>"#
    ).map(BangumiHTMLParser.stripTags) ?? ""

    let main = BangumiTimelinePost(
      id: mainID,
      userName: userName,
      userID: userID,
      avatarURL: avatarURL,
      date: date,
      text: mainText,
      htmlText: mainHTML.isEmpty ? nil : mainHTML
    )

    let repliesHTML = BangumiHTMLParser.firstCapture(
      in: content,
      pattern: #"<ul class="subReply">(.*?)</ul>"#
    ) ?? ""
    let replies = BangumiHTMLParser.matches(
      in: repliesHTML,
      pattern: #"<li[^>]*class="reply_item"[^>]*>(.*?)(?=<li[^>]*class="reply_item"|$)"#
    ).compactMap { match -> BangumiTimelinePost? in
      let block = BangumiHTMLParser.capture(repliesHTML, from: match, group: 0) ?? ""
      let rawText = BangumiHTMLParser.stripTags(block)
      let replyHTML = {
        guard let splitRange = block.range(of: "-</span> ") else { return block }
        return String(block[splitRange.upperBound...])
      }()
      let replyText = BangumiHTMLParser.stripTags(replyHTML).isEmpty ? rawText : BangumiHTMLParser.stripTags(replyHTML)
      guard !replyText.isEmpty else { return nil }

      let replyID = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="cmt_reply"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags)?
        .replacingOccurrences(of: "@", with: "") ?? UUID().uuidString
      let replyName = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="cmt_reply"[^>]*>.*?</a>\s*<a[^>]*class="l"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户"
      let replyUserID = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="l"[^>]*href="/user/([^"/]+)""#
      )

      return BangumiTimelinePost(
        id: replyID,
        userName: replyName,
        userID: replyUserID,
        avatarURL: replyID == main.id ? main.avatarURL : nil,
        date: "",
        text: replyText,
        htmlText: replyHTML.isEmpty ? nil : replyHTML
      )
    }

    return BangumiTimelineDetail(main: main, replies: replies)
  }
}

private enum BangumiRakuenParser {
  static func parse(html: String, baseURL: URL) -> [BangumiRakuenItem] {
    let content = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<div id="eden_tpc_list"><ul>"#,
      end: #"</ul></div>"#
    ) ?? html

    return BangumiHTMLParser.splitBlocks(in: content, marker: "<li").compactMap { row in
      let anchors = BangumiHTMLParser.anchors(in: row)
      let topic = anchors.first(where: {
        $0.href.contains("/rakuen/topic/") ||
          $0.href.contains("/group/topic/") ||
          $0.href.contains("/subject/topic/") ||
          $0.href.contains("/character/") ||
          $0.href.contains("/person/")
      })

      guard let topic else { return nil }

      let metaAnchors = anchors.filter { $0.href != topic.href }
      let userAnchor = metaAnchors.first(where: { $0.href.contains("/user/") })
      let groupAnchor = metaAnchors.first(where: {
        $0.href.contains("/group/") || $0.href.contains("/subject/")
      })
      let avatarURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: row,
          pattern: #"background-image:url\((?:'|")?(.+?)(?:'|")?\)"#,
          group: 1
        ),
        baseURL: baseURL
      )
      let userName = userAnchor?.text ??
        BangumiHTMLParser.decodeEntities(
          BangumiHTMLParser.firstCapture(in: row, pattern: #"title="([^"]+)""#) ?? ""
        )
      let userID = BangumiHTMLParser.firstCapture(in: row, pattern: #"data-user="([^"]+)""#)
      let replyCount = BangumiHTMLParser.firstCapture(
        in: row,
        pattern: #"<small[^>]*>(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags)
      let trailingText = BangumiHTMLParser.stripTags(row)
      let time = trailingText
        .components(separatedBy: " ")
        .suffix(2)
        .joined(separator: " ")

      return BangumiRakuenItem(
        id: topic.href,
        title: topic.text,
        topicURL: BangumiHTMLParser.absoluteURL(from: topic.href, baseURL: baseURL),
        userName: userName.isEmpty ? "Bangumi 用户" : userName,
        userID: userID,
        avatarURL: avatarURL,
        groupName: groupAnchor?.text.isEmpty == false ? groupAnchor?.text : nil,
        groupURL: BangumiHTMLParser.absoluteURL(from: groupAnchor?.href, baseURL: baseURL),
        replyCount: replyCount?.isEmpty == true ? nil : replyCount,
        time: time
      )
    }
  }
}

private enum BangumiRakuenTopicParser {
  static func parse(html: String, baseURL: URL) -> BangumiRakuenTopicDetail {
    let title = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="pageHeader".*?<h1[^>]*>(.*?)</h1>"#
    ).map(BangumiHTMLParser.stripTags) ?? "帖子详情"

    let groupURL = BangumiHTMLParser.absoluteURL(
      from: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<div id="pageHeader".*?<a[^>]*class="avatar"[^>]*href="([^"]+)""#
      ),
      baseURL: baseURL
    )
    let groupName = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="pageHeader".*?<a[^>]*class="avatar"[^>]*(?:title="([^"]*)")?[^>]*>(.*?)</a>"#,
      group: 1
    ).flatMap { raw in
      let trimmed = BangumiHTMLParser.decodeEntities(raw)
      return trimmed.isEmpty ? nil : trimmed
    } ?? BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="pageHeader".*?<a[^>]*class="avatar"[^>]*(?:title="[^"]*")?[^>]*>(.*?)</a>"#,
      group: 1
    ).map(BangumiHTMLParser.stripTags)

    let topicID = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="post_(\d+)" class="postTopic"#
    ) ?? UUID().uuidString
    let avatarURL = BangumiHTMLParser.parseAvatarURL(
      from: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<div id="post_\d+" class="postTopic.*?<span class="avatarNeue"[^>]*style="([^"]+)""#
      ) ?? "",
      baseURL: baseURL
    )
    let userURL = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="post_\d+" class="postTopic.*?<strong>\s*<a[^>]*href="([^"]+)"[^>]*class="l""#
    )
    let infoText = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="post_\d+" class="postTopic.*?<div class="re_info">.*?<small>(.*?)</small>"#
    ).map(BangumiHTMLParser.stripTags) ?? ""
    let infoParts = infoText.components(separatedBy: " - ")
    let messageHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div class="topic_content">(.*?)</div>"#
    ) ?? ""
    let message = BangumiHTMLParser.stripTags(messageHTML)

    let topic = BangumiRakuenTopic(
      id: topicID,
      title: title,
      groupName: groupName?.isEmpty == true ? nil : groupName,
      groupURL: groupURL,
      userName: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<div id="post_\d+" class="postTopic.*?<strong>\s*<a[^>]*class="l"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户",
      userID: BangumiHTMLParser.firstCapture(in: userURL ?? "", pattern: #"/user/([^"/]+)"#),
      userSign: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<div id="post_\d+" class="postTopic.*?<span class="tip_j">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags),
      avatarURL: avatarURL,
      floor: infoParts.first,
      time: infoParts.count > 1 ? infoParts.dropFirst().joined(separator: " - ") : infoText,
      message: message,
      htmlMessage: messageHTML.isEmpty ? nil : messageHTML
    )

    let commentSection = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<div id="comment_list""#,
      end: #"<div id="footer">"#
    ) ?? ""
    let commentMatches = BangumiHTMLParser.matches(
      in: commentSection,
      pattern: #"<div id="post_(\d+)" class="row_reply.*?>(.*?)(?=<div id="post_\d+" class="row_reply|$)"#
    )

    let comments = commentMatches.compactMap { match -> BangumiRakuenComment? in
      let id = BangumiHTMLParser.capture(commentSection, from: match, group: 1) ?? UUID().uuidString
      let block = BangumiHTMLParser.capture(commentSection, from: match, group: 0) ?? ""
      let info = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small>(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      let infoParts = info.components(separatedBy: " - ")
      let messageHTML = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<div class="reply_content".*?<div class="message">(.*?)</div>"#
      ) ?? ""
      let message = BangumiHTMLParser.stripTags(messageHTML)

      guard !message.isEmpty else { return nil }

      let subReplyMatches = BangumiHTMLParser.matches(
        in: block,
        pattern: #"<div id="post_(\d+)" class="sub_reply_bg.*?>(.*?)(?=<div id="post_\d+" class="sub_reply_bg|$)"#
      )
      let subReplies = subReplyMatches.compactMap { match -> BangumiRakuenSubReply? in
        let subBlock = BangumiHTMLParser.capture(block, from: match, group: 0) ?? ""
        let subInfo = BangumiHTMLParser.firstCapture(
          in: subBlock,
          pattern: #"<small>(.*?)</small>"#
        ).map(BangumiHTMLParser.stripTags) ?? ""
        let subInfoParts = subInfo.components(separatedBy: " - ")
        let subMessageHTML = BangumiHTMLParser.firstCapture(
          in: subBlock,
          pattern: #"<div class="cmt_sub_content">(.*?)</div>"#
        ) ?? ""
        let subMessage = BangumiHTMLParser.stripTags(subMessageHTML)

        guard !subMessage.isEmpty else { return nil }

        return BangumiRakuenSubReply(
          id: BangumiHTMLParser.capture(block, from: match, group: 1) ?? UUID().uuidString,
          userName: BangumiHTMLParser.firstCapture(
            in: subBlock,
            pattern: #"<strong>\s*<a[^>]*class="l"[^>]*>(.*?)</a>"#
          ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户",
          userID: BangumiHTMLParser.firstCapture(
            in: subBlock,
            pattern: #"<a[^>]*href="/user/([^"/]+)""#
          ),
          userSign: BangumiHTMLParser.firstCapture(
            in: subBlock,
            pattern: #"<span class="tip_j">(.*?)</span>"#
          ).map(BangumiHTMLParser.stripTags),
          avatarURL: BangumiHTMLParser.parseAvatarURL(
            from: BangumiHTMLParser.firstCapture(
              in: subBlock,
              pattern: #"<span class="avatarNeue"[^>]*style="([^"]+)""#
            ) ?? "",
            baseURL: baseURL
          ),
          floor: subInfoParts.first,
          time: subInfoParts.count > 1 ? subInfoParts.dropFirst().joined(separator: " - ") : subInfo,
          message: subMessage,
          htmlMessage: subMessageHTML.isEmpty ? nil : subMessageHTML
        )
      }

      return BangumiRakuenComment(
        id: id,
        userName: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<strong>\s*<a[^>]*class="l"[^>]*>(.*?)</a>"#
        ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户",
        userID: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<a[^>]*href="/user/([^"/]+)""#
        ),
        userSign: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<span class="tip_j">(.*?)</span>"#
        ).map(BangumiHTMLParser.stripTags),
        avatarURL: BangumiHTMLParser.parseAvatarURL(
          from: BangumiHTMLParser.firstCapture(
            in: block,
            pattern: #"<span class="avatarNeue"[^>]*style="([^"]+)""#
          ) ?? "",
          baseURL: baseURL
        ),
        floor: infoParts.first,
        time: infoParts.count > 1 ? infoParts.dropFirst().joined(separator: " - ") : info,
        message: message,
        htmlMessage: messageHTML.isEmpty ? nil : messageHTML,
        subReplies: subReplies
      )
    }

    return BangumiRakuenTopicDetail(topic: topic, comments: comments)
  }
}

private enum BangumiUserProfileParser {
  static func parse(html: String, userID: String, baseURL: URL) -> BangumiUserProfile {
    let profileHeader = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<div class="idBadgerNeue"#,
      end: #"<div class="user_box""#
    ) ?? html

    let displayName = BangumiHTMLParser.firstCapture(
      in: profileHeader,
      pattern: #"<a[^>]*class="nameSingle"[^>]*>(.*?)</a>"#
    ).map(BangumiHTMLParser.stripTags) ?? BangumiHTMLParser.firstCapture(
      in: profileHeader,
      pattern: #"<h1[^>]*>(.*?)</h1>"#
    ).map(BangumiHTMLParser.stripTags) ?? userID

    let avatarURL = BangumiHTMLParser.absoluteURL(
      from: BangumiHTMLParser.firstCapture(
        in: profileHeader,
        pattern: #"<img[^>]*class="avatar"[^>]*src="([^"]+)""#
      ),
      baseURL: baseURL
    ) ?? BangumiHTMLParser.parseAvatarURL(
      from: BangumiHTMLParser.firstCapture(
        in: profileHeader,
        pattern: #"<span class="avatarNeue"[^>]*style="([^"]+)""#
      ) ?? "",
      baseURL: baseURL
    )

    let sign = BangumiHTMLParser.firstCapture(
      in: profileHeader,
      pattern: #"<span class="tip"[^>]*>(.*?)</span>"#
    ).map(BangumiHTMLParser.stripTags)

    let bio = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div class="bio"[^>]*>(.*?)</div>"#
    ).map(BangumiHTMLParser.stripTags)

    let joinedAt = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"Bangumi\s*(?:注册|joined)\s*[：:]?\s*([^<]+)"#
    ).map(BangumiHTMLParser.decodeEntities)

    let location = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="userLocation"[^>]*>(.*?)</span>"#
    ).map(BangumiHTMLParser.stripTags)

    return BangumiUserProfile(
      username: userID,
      displayName: displayName.isEmpty ? userID : displayName,
      avatarURL: avatarURL,
      sign: sign?.isEmpty == true ? nil : sign,
      bio: bio?.isEmpty == true ? nil : bio,
      joinedAt: joinedAt?.isEmpty == true ? nil : joinedAt,
      location: location?.isEmpty == true ? nil : location
    )
  }
}

private enum BangumiError: LocalizedError {
  case invalidURL
  case missingToken
  case invalidResponse
  case oauthCancelled
  case oauthMissingCode

  var errorDescription: String? {
    switch self {
    case .invalidURL: "URL 无效"
    case .missingToken: "当前未登录"
    case .invalidResponse: "服务返回异常"
    case .oauthCancelled: "登录已取消"
    case .oauthMissingCode: "未能从回调中解析授权码"
    }
  }
}

private final class BangumiKeychainStore {
  private let service = "tv.bangumi.czy0729.native.auth"

  func save(_ data: Data, for key: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]
    SecItemDelete(query as CFDictionary)

    let newItem: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecValueData: data
    ]
    SecItemAdd(newItem as CFDictionary, nil)
  }

  func load(for key: String) -> Data? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else { return nil }
    return item as? Data
  }

  func remove(for key: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]
    SecItemDelete(query as CFDictionary)
  }
}

private final class BangumiSessionStore: ObservableObject {
  @Published private(set) var token: BangumiToken?
  @Published private(set) var currentUser: BangumiUser?

  private let keychain = BangumiKeychainStore()
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init() {
    restore()
  }

  var isAuthenticated: Bool {
    token != nil
  }

  func restore() {
    if let tokenData = keychain.load(for: "token"),
       let decodedToken = try? decoder.decode(BangumiToken.self, from: tokenData) {
      token = decodedToken
    }

    if let userData = keychain.load(for: "user"),
       let decodedUser = try? decoder.decode(BangumiUser.self, from: userData) {
      currentUser = decodedUser
    }
  }

  func update(token: BangumiToken, user: BangumiUser) {
    self.token = token
    currentUser = user

    if let tokenData = try? encoder.encode(token) {
      keychain.save(tokenData, for: "token")
    }
    if let userData = try? encoder.encode(user) {
      keychain.save(userData, for: "user")
    }
  }

  func signOut() {
    token = nil
    currentUser = nil
    keychain.remove(for: "token")
    keychain.remove(for: "user")
  }
}

private final class BangumiSettingsStore: ObservableObject {
  @Published var preferredTheme: PreferredTheme {
    didSet {
      userDefaults.set(preferredTheme.rawValue, forKey: "native.preferredTheme")
    }
  }

  @Published private(set) var recentSearches: [String]

  private let userDefaults = UserDefaults.standard

  init() {
    preferredTheme = PreferredTheme(rawValue: userDefaults.string(forKey: "native.preferredTheme") ?? "") ?? .system
    recentSearches = userDefaults.stringArray(forKey: "native.recentSearches") ?? []
  }

  func rememberSearch(_ query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    var next = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
    next.insert(trimmed, at: 0)
    recentSearches = Array(next.prefix(10))
    userDefaults.set(recentSearches, forKey: "native.recentSearches")
  }

  func removeSearch(_ query: String) {
    recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
    userDefaults.set(recentSearches, forKey: "native.recentSearches")
  }

  func clearSearches() {
    recentSearches = []
    userDefaults.removeObject(forKey: "native.recentSearches")
  }
}

private final class BangumiAPIClient {
  struct Config {
    let apiBase = URL(string: "https://api.bgm.tv")!
    let apiV0Base = URL(string: "https://api.bgm.tv/v0")!
    let webBase = URL(string: "https://bgm.tv")!
    let nextBase = URL(string: "https://next.bgm.tv/p1")!
    let appID = "bgm8885c4d524cd61fc"
    let appSecret = "1da52e7834bbb73cca90302f9ddbc8dd"
    let callbackURL = URL(string: "https://bgm.tv/dev/app")!
  }

  let config = Config()
  private let sessionStore: BangumiSessionStore
  private let urlSession: URLSession

  init(sessionStore: BangumiSessionStore) {
    self.sessionStore = sessionStore

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .useProtocolCachePolicy
    configuration.urlCache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 30
    urlSession = URLSession(configuration: configuration)
  }

  func makeAuthorizeURL() -> URL {
    var components = URLComponents(url: config.webBase.appending(path: "/oauth/authorize"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: config.appID),
      URLQueryItem(name: "redirect_uri", value: config.callbackURL.absoluteString)
    ]
    return components.url!
  }

  func exchangeCodeForToken(code: String) async throws -> BangumiToken {
    var request = URLRequest(url: config.webBase.appending(path: "/oauth/access_token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = formData([
      "grant_type": "authorization_code",
      "client_id": config.appID,
      "client_secret": config.appSecret,
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
      let html = try? await fetchWebHTML(url: config.webBase.appending(path: "/subject/\(subjectID)"))
      return html.map(BangumiSubjectWebParser.parseEpisodes) ?? []
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
    queryItems.append(URLQueryItem(name: "state", value: String(Int(Date().timeIntervalSince1970))))
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
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        return "\(key)=\(encodedValue)"
      }
      .joined(separator: "&")
    return Data(body.utf8)
  }
}

private final class BangumiAuthService {
  private let apiClient: BangumiAPIClient
  private let sessionStore: BangumiSessionStore

  init(apiClient: BangumiAPIClient, sessionStore: BangumiSessionStore) {
    self.apiClient = apiClient
    self.sessionStore = sessionStore
  }

  func signInWithAuthorizationCode(_ code: String) async throws {
    let token = try await apiClient.exchangeCodeForToken(code: code)
    let user = try await apiClient.fetchCurrentUser(using: token)
    await MainActor.run {
      sessionStore.update(token: token, user: user)
    }
  }

  func signInWithToken(_ rawToken: String) async throws {
    let token = BangumiToken(
      accessToken: rawToken,
      tokenType: "Bearer",
      expiresIn: 604_800,
      refreshToken: nil,
      userID: nil
    )
    let user = try await apiClient.fetchCurrentUser(using: token)
    await MainActor.run {
      sessionStore.update(token: token, user: user)
    }
  }
}

private final class DiscoveryRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetchCalendar() async throws -> [BangumiCalendarDay] {
    try await apiClient.fetchCalendar()
  }
}

private final class SearchRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func search(query: BangumiSearchQuery) async throws -> [BangumiSubjectSummary] {
    switch query.matchMode {
    case .precise:
      try await apiClient.searchSubjects(keyword: query.keyword, type: query.type)
    case .fuzzy:
      try await apiClient.searchSubjectsFromWeb(keyword: query.keyword, type: query.type)
    }
  }
}

private final class TimelineRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetch(page: Int, filter: TimelineFilter) async throws -> BangumiTimelinePage {
    try await apiClient.fetchTimeline(page: page, filter: filter)
  }

  func fetchDetail(url: URL) async throws -> BangumiTimelineDetail {
    try await apiClient.fetchTimelineDetail(url: url)
  }
}

private final class RakuenRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetch(filter: RakuenFilter) async throws -> [BangumiRakuenItem] {
    try await apiClient.fetchRakuen(filter: filter)
  }

  func fetchTopic(url: URL) async throws -> BangumiRakuenTopicDetail {
    try await apiClient.fetchRakuenTopic(url: url)
  }
}

private final class SubjectRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetchSubject(id: Int) async throws -> BangumiSubject {
    try await apiClient.fetchSubject(id: id)
  }

  func fetchEpisodes(subjectID: Int) async throws -> [BangumiEpisode] {
    try await apiClient.fetchEpisodes(subjectID: subjectID)
  }

  func fetchCollection(subjectID: Int) async throws -> BangumiSubjectCollectionRecord {
    try await apiClient.fetchCollection(subjectID: subjectID)
  }

  func fetchEpisodeCollections(subjectID: Int) async throws -> [BangumiEpisodeCollection] {
    try await apiClient.fetchEpisodeCollections(subjectID: subjectID)
  }

  func fetchSubjectComments(subjectID: Int) async throws -> [BangumiSubjectComment] {
    try await apiClient.fetchSubjectComments(subjectID: subjectID)
  }

  func fetchSubjectPresentation(subjectID: Int) async throws -> BangumiSubjectPresentation {
    try await apiClient.fetchSubjectPresentation(subjectID: subjectID)
  }

  func updateCollection(subjectID: Int, payload: CollectionUpdatePayload) async throws {
    try await apiClient.updateCollection(subjectID: subjectID, payload: payload)
  }

  func updateEpisodeCollection(episodeID: Int, type: BangumiEpisodeCollectionType) async throws {
    try await apiClient.updateEpisodeCollection(episodeID: episodeID, type: type)
  }

  func markEpisodeWatched(episodeID: Int) async throws {
    try await apiClient.markEpisodeWatched(episodeID: episodeID)
  }

  func updateWatchedProgress(
    subjectID: Int,
    watchedEpisodes: Int? = nil,
    watchedVolumes: Int? = nil
  ) async throws {
    try await apiClient.updateWatchedProgress(
      subjectID: subjectID,
      watchedEpisodes: watchedEpisodes,
      watchedVolumes: watchedVolumes
    )
  }
}

private extension UNUserNotificationCenter {
  func bangumiNotificationSettings() async -> UNNotificationSettings {
    await withCheckedContinuation { continuation in
      getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }
  }

  func bangumiRequestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      requestAuthorization(options: options) { granted, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: granted)
        }
      }
    }
  }
}

private final class BangumiNotificationStore: NSObject, ObservableObject {
  static let backgroundRefreshIdentifier = "tv.bangumi.czy0729.subject-updates"
  static let subjectIDUserInfoKey = "subjectID"

  @Published private(set) var permissionState: BangumiNotificationPermissionState = .notDetermined
  @Published private(set) var subscriptions: [BangumiSubjectNotificationSubscription] = []
  @Published private(set) var isCheckingUpdates = false
  @Published private(set) var updatingSubjectIDs = Set<Int>()
  @Published private(set) var lastCheckedAt: Date?
  @Published var statusMessage: String?
  @Published var pendingOpenedSubjectID: Int?

  private let subjectRepository: SubjectRepository
  private let notificationCenter = UNUserNotificationCenter.current()
  private let userDefaults = UserDefaults.standard
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let automaticCheckInterval: TimeInterval = 15 * 60
  private let backgroundRefreshLeadTime: TimeInterval = 30 * 60
  private let subscriptionsKey = "native.notification.subscriptions"
  private let lastCheckedAtKey = "native.notification.lastCheckedAt"
  private var hasRegisteredBackgroundRefresh = false

  init(subjectRepository: SubjectRepository) {
    self.subjectRepository = subjectRepository
    super.init()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    decoder.dateDecodingStrategy = .millisecondsSince1970
    loadPersistedState()
    notificationCenter.delegate = self
    registerBackgroundRefreshIfNeeded()

    Task {
      await refreshPermissionState()
    }
  }

  func subscription(for subjectID: Int) -> BangumiSubjectNotificationSubscription? {
    subscriptions.first(where: { $0.subjectID == subjectID && $0.isEnabled })
  }

  func isSubscribed(subjectID: Int) -> Bool {
    subscription(for: subjectID) != nil
  }

  @MainActor
  func prepareForAppLaunch() async {
    await refreshPermissionState()
    await performAutomaticCheckIfNeeded(force: false)
  }

  @MainActor
  func handleScenePhase(_ phase: ScenePhase) async {
    switch phase {
    case .active:
      await refreshPermissionState()
      await performAutomaticCheckIfNeeded(force: false)
    case .background:
      scheduleBackgroundRefresh()
    case .inactive:
      break
    @unknown default:
      break
    }
  }

  @MainActor
  func refreshPermissionState() async {
    let settings = await notificationCenter.bangumiNotificationSettings()
    permissionState = Self.permissionState(from: settings.authorizationStatus)
  }

  @MainActor
  func toggleSubscription(subject: BangumiSubject, episodes: [BangumiEpisode]) async {
    if isSubscribed(subjectID: subject.id) {
      disableSubscription(subjectID: subject.id)
      return
    }

    updatingSubjectIDs.insert(subject.id)
    defer { updatingSubjectIDs.remove(subject.id) }

    if permissionState == .notDetermined {
      do {
        _ = try await notificationCenter.bangumiRequestAuthorization(options: [.alert, .badge, .sound])
      } catch {
        statusMessage = "通知权限请求失败：\(error.localizedDescription)"
      }
      await refreshPermissionState()
    }

    let latestEpisode = Self.latestEpisode(in: episodes)
    let now = Date()
    let subscription = BangumiSubjectNotificationSubscription(
      subjectID: subject.id,
      title: subject.nameCN ?? subject.name,
      subtitle: subject.nameCN == nil || subject.nameCN == subject.name ? nil : subject.name,
      coverURLString: subject.images?.best?.absoluteString,
      subjectTypeTitle: SubjectType.title(for: subject.type),
      latestEpisodeID: latestEpisode?.id,
      latestEpisodeSort: latestEpisode?.sort,
      latestEpisodeAirdate: latestEpisode?.airdate,
      latestEpisodeTitle: Self.episodeDisplayTitle(for: latestEpisode),
      lastKnownEpisodeCount: episodes.count,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
      lastCheckedAt: nil,
      lastNotifiedEpisodeID: nil,
      lastErrorMessage: nil
    )
    upsert(subscription)
    scheduleBackgroundRefresh()

    if permissionState.canDeliverNotifications {
      statusMessage = "已为《\(subscription.title)》开启更新提醒。"
    } else {
      statusMessage = "已记录《\(subscription.title)》的更新提醒，授权系统通知后会开始推送。"
    }
  }

  @MainActor
  func disableSubscription(subjectID: Int) {
    guard let target = subscription(for: subjectID) else { return }
    subscriptions.removeAll { $0.subjectID == subjectID }
    persistSubscriptions()
    scheduleBackgroundRefresh()
    statusMessage = "已关闭《\(target.title)》的更新提醒。"
  }

  @MainActor
  func disableAllSubscriptions() {
    guard !subscriptions.isEmpty else { return }
    subscriptions = []
    persistSubscriptions()
    cancelBackgroundRefresh()
    statusMessage = "已关闭全部条目提醒。"
  }

  @MainActor
  func performManualCheck() async {
    await runUpdateCheck(manual: true)
  }

  @MainActor
  func consumePendingOpenedSubjectID() {
    pendingOpenedSubjectID = nil
  }

  private func loadPersistedState() {
    if let data = userDefaults.data(forKey: subscriptionsKey),
       let decoded = try? decoder.decode([BangumiSubjectNotificationSubscription].self, from: data) {
      subscriptions = decoded.filter(\.isEnabled)
    }

    lastCheckedAt = userDefaults.object(forKey: lastCheckedAtKey) as? Date
  }

  @MainActor
  private func performAutomaticCheckIfNeeded(force: Bool) async {
    let hasActiveSubscriptions = subscriptions.contains(where: \.isEnabled)
    guard hasActiveSubscriptions else {
      cancelBackgroundRefresh()
      return
    }

    if !force,
       let lastCheckedAt,
       Date().timeIntervalSince(lastCheckedAt) < automaticCheckInterval {
      return
    }

    await runUpdateCheck(manual: false)
  }

  @MainActor
  private func runUpdateCheck(manual: Bool) async {
    let activeSubscriptions = subscriptions.filter(\.isEnabled)
    guard !activeSubscriptions.isEmpty else {
      if manual {
        statusMessage = "还没有订阅任何条目提醒。"
      }
      cancelBackgroundRefresh()
      return
    }

    isCheckingUpdates = true
    defer {
      isCheckingUpdates = false
      scheduleBackgroundRefresh()
    }

    let now = Date()
    var nextSubscriptions = subscriptions
    var updatesCount = 0
    var failedCount = 0

    for index in nextSubscriptions.indices {
      guard nextSubscriptions[index].isEnabled else { continue }

      var subscription = nextSubscriptions[index]
      do {
        let episodes = try await subjectRepository.fetchEpisodes(subjectID: subscription.subjectID)
        let latestEpisode = Self.latestEpisode(in: episodes)
        let checkResult = BangumiSubjectUpdateCheckResult(
          subjectID: subscription.subjectID,
          hasUpdate: Self.hasEpisodeUpdate(
            latestEpisode,
            comparedTo: subscription,
            episodeCount: episodes.count
          ),
          latestEpisode: latestEpisode,
          checkedAt: now,
          errorMessage: nil
        )

        subscription.latestEpisodeID = latestEpisode?.id
        subscription.latestEpisodeSort = latestEpisode?.sort
        subscription.latestEpisodeAirdate = latestEpisode?.airdate
        subscription.latestEpisodeTitle = Self.episodeDisplayTitle(for: latestEpisode)
        subscription.lastKnownEpisodeCount = episodes.count
        subscription.lastCheckedAt = checkResult.checkedAt
        subscription.updatedAt = checkResult.checkedAt
        subscription.lastErrorMessage = nil

        if checkResult.hasUpdate, let latestEpisode {
          updatesCount += 1
          if permissionState.canDeliverNotifications {
            await deliverNotification(for: subscription, latestEpisode: latestEpisode)
            subscription.lastNotifiedEpisodeID = latestEpisode.id
          }
        }
      } catch {
        failedCount += 1
        subscription.lastCheckedAt = now
        subscription.updatedAt = now
        subscription.lastErrorMessage = error.localizedDescription
      }

      nextSubscriptions[index] = subscription
    }

    subscriptions = nextSubscriptions.filter(\.isEnabled)
    lastCheckedAt = now
    persistSubscriptions()
    userDefaults.set(now, forKey: lastCheckedAtKey)

    if manual {
      if failedCount > 0, updatesCount == 0 {
        statusMessage = "检查完成，\(failedCount) 个条目读取失败。"
      } else if updatesCount > 0 {
        statusMessage = permissionState.canDeliverNotifications
          ? "检查完成，发现 \(updatesCount) 个条目有新章节。"
          : "检查完成，发现 \(updatesCount) 个条目有新章节，但系统通知尚未授权。"
      } else {
        statusMessage = "已经是最新进度，没有发现新章节。"
      }
    }
  }

  @MainActor
  private func deliverNotification(
    for subscription: BangumiSubjectNotificationSubscription,
    latestEpisode: BangumiEpisode
  ) async {
    let content = UNMutableNotificationContent()
    content.title = "《\(subscription.title)》有更新"
    content.body = "\(Self.episodeDisplayTitle(for: latestEpisode) ?? subscription.latestEpisodeLabel) 已加入条目时间线，点开继续查看详情。"
    content.sound = .default
    content.userInfo = [Self.subjectIDUserInfoKey: subscription.subjectID]

    let request = UNNotificationRequest(
      identifier: "subject-update-\(subscription.subjectID)-\(latestEpisode.id)",
      content: content,
      trigger: nil
    )

    do {
      try await notificationCenter.add(request)
    } catch {
      statusMessage = "系统通知发送失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  private func upsert(_ subscription: BangumiSubjectNotificationSubscription) {
    if let index = subscriptions.firstIndex(where: { $0.subjectID == subscription.subjectID }) {
      subscriptions[index] = subscription
    } else {
      subscriptions.insert(subscription, at: 0)
    }
    persistSubscriptions()
  }

  private func persistSubscriptions() {
    if let data = try? encoder.encode(subscriptions) {
      userDefaults.set(data, forKey: subscriptionsKey)
    }
  }

  private func registerBackgroundRefreshIfNeeded() {
    guard !hasRegisteredBackgroundRefresh else { return }
    hasRegisteredBackgroundRefresh = true

    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundRefreshIdentifier, using: nil) { [weak self] task in
      guard let self, let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }

      self.handleBackgroundRefresh(task: refreshTask)
    }
  }

  private func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh()
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    Task { @MainActor [weak self] in
      guard let self else {
        task.setTaskCompleted(success: false)
        return
      }

      await self.refreshPermissionState()
      await self.runUpdateCheck(manual: false)
      task.setTaskCompleted(success: true)
    }
  }

  private func scheduleBackgroundRefresh() {
    let activeSubscriptions = subscriptions.contains(where: \.isEnabled)
    guard activeSubscriptions else {
      cancelBackgroundRefresh()
      return
    }

    let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: backgroundRefreshLeadTime)
    try? BGTaskScheduler.shared.submit(request)
  }

  private func cancelBackgroundRefresh() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshIdentifier)
  }

  private static func permissionState(from status: UNAuthorizationStatus) -> BangumiNotificationPermissionState {
    switch status {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    case .provisional: .provisional
    case .ephemeral: .ephemeral
    @unknown default: .notDetermined
    }
  }

  private static func latestEpisode(in episodes: [BangumiEpisode]) -> BangumiEpisode? {
    episodes.max { lhs, rhs in
      let lhsSort = lhs.sort ?? -Double.greatestFiniteMagnitude
      let rhsSort = rhs.sort ?? -Double.greatestFiniteMagnitude
      if lhsSort == rhsSort {
        return lhs.id < rhs.id
      }
      return lhsSort < rhsSort
    }
  }

  private static func episodeDisplayTitle(for episode: BangumiEpisode?) -> String? {
    guard let episode else { return nil }

    let prefix: String
    if let sort = episode.sort {
      if sort.rounded(.towardZero) == sort {
        prefix = "第 \(Int(sort)) 集"
      } else {
        prefix = "第 \(sort.formatted(.number.precision(.fractionLength(1)))) 集"
      }
    } else {
      prefix = "章节"
    }

    let title = episode.nameCN ?? episode.name
    guard let title, !title.isEmpty else { return prefix }
    return "\(prefix) · \(title)"
  }

  private static func hasEpisodeUpdate(
    _ latestEpisode: BangumiEpisode?,
    comparedTo subscription: BangumiSubjectNotificationSubscription,
    episodeCount: Int
  ) -> Bool {
    guard let latestEpisode else {
      return false
    }

    if let previousEpisodeID = subscription.latestEpisodeID,
       previousEpisodeID == latestEpisode.id {
      return false
    }

    if let previousSort = subscription.latestEpisodeSort,
       let latestSort = latestEpisode.sort {
      if latestSort > previousSort {
        return true
      }
      if latestSort < previousSort {
        return false
      }
    }

    if let previousEpisodeID = subscription.latestEpisodeID {
      return latestEpisode.id > previousEpisodeID
    }

    return subscription.lastKnownEpisodeCount == 0 && episodeCount > 0
  }
}

extension BangumiNotificationStore: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let subjectID = (userInfo[Self.subjectIDUserInfoKey] as? Int) ??
      (userInfo[Self.subjectIDUserInfoKey] as? String).flatMap(Int.init)

    if let subjectID {
      Task { @MainActor [weak self] in
        self?.pendingOpenedSubjectID = subjectID
      }
    }

    completionHandler()
  }
}

private final class UserRepository {
  private let apiClient: BangumiAPIClient
  private let sessionStore: BangumiSessionStore

  init(apiClient: BangumiAPIClient, sessionStore: BangumiSessionStore) {
    self.apiClient = apiClient
    self.sessionStore = sessionStore
  }

  func refreshCurrentUser() async throws -> BangumiUser {
    let user = try await apiClient.fetchCurrentUser()
    if let token = sessionStore.token {
      await MainActor.run {
        sessionStore.update(token: token, user: user)
      }
    }
    return user
  }

  func fetchWatchingCollections(subjectType: SubjectType = .anime, limit: Int = 20) async throws -> [BangumiCollectionItem] {
    let identifier = sessionStore.currentUser?.username ?? String(sessionStore.currentUser?.id ?? 0)
    return try await apiClient.fetchWatchingCollections(userID: identifier, subjectType: subjectType, limit: limit)
  }

  func fetchUserProfile(userID: String) async throws -> BangumiUserProfile {
    try await apiClient.fetchUserProfile(userID: userID)
  }

  func fetchWatchingCollections(
    userID: String,
    subjectType: SubjectType = .anime,
    limit: Int = 20
  ) async throws -> [BangumiCollectionItem] {
    try await apiClient.fetchWatchingCollections(userID: userID, subjectType: subjectType, limit: limit)
  }
}

private final class BangumiAppModel: ObservableObject {
  @Published var activeTab: BangumiTab = .home
  @Published var isShowingSearch = false
  @Published var isShowingLogin = false
  @Published var isShowingNotifications = false
  @Published var presentedRoute: BangumiModalRoute?
  @Published var presentedImage: BangumiImagePreview?

  let sessionStore: BangumiSessionStore
  let settingsStore: BangumiSettingsStore
  let apiClient: BangumiAPIClient
  let authService: BangumiAuthService
  let discoveryRepository: DiscoveryRepository
  let searchRepository: SearchRepository
  let timelineRepository: TimelineRepository
  let rakuenRepository: RakuenRepository
  let subjectRepository: SubjectRepository
  let userRepository: UserRepository
  let notificationStore: BangumiNotificationStore

  init() {
    sessionStore = BangumiSessionStore()
    settingsStore = BangumiSettingsStore()
    apiClient = BangumiAPIClient(sessionStore: sessionStore)
    authService = BangumiAuthService(apiClient: apiClient, sessionStore: sessionStore)
    discoveryRepository = DiscoveryRepository(apiClient: apiClient)
    searchRepository = SearchRepository(apiClient: apiClient)
    timelineRepository = TimelineRepository(apiClient: apiClient)
    rakuenRepository = RakuenRepository(apiClient: apiClient)
    subjectRepository = SubjectRepository(apiClient: apiClient)
    userRepository = UserRepository(apiClient: apiClient, sessionStore: sessionStore)
    notificationStore = BangumiNotificationStore(subjectRepository: subjectRepository)
  }

  var preferredColorScheme: ColorScheme? {
    settingsStore.preferredTheme.colorScheme
  }

  func present(url: URL) {
    guard let host = url.host?.lowercased() else {
      presentedRoute = .web(url, "网页")
      return
    }

    guard host.contains("bgm.tv") || host.contains("bangumi.tv") else {
      presentedRoute = .web(url, "网页")
      return
    }

    let path = url.path
    if let subjectID = Int(BangumiHTMLParser.firstCapture(in: path, pattern: #"^/subject/(\d+)"#) ?? "") {
      presentedRoute = .subject(subjectID)
      return
    }

    if let userID = BangumiHTMLParser.firstCapture(in: path, pattern: #"^/user/([^/]+)"#),
       !userID.isEmpty {
      presentedRoute = .user(userID)
      return
    }

    if path.contains("/timeline/status/") {
      presentedRoute = .timeline(url)
      return
    }

    if path.contains("/rakuen/topic/") || path.contains("/group/topic/") || path.contains("/subject/topic/") {
      presentedRoute = .rakuen(url)
      return
    }

    presentedRoute = .web(url, "网页")
  }

  func presentImage(_ url: URL) {
    presentedImage = BangumiImagePreview(url: url)
  }
}

private struct BangumiRootView: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()

      TabView(selection: $model.activeTab) {
        NavigationStack {
          HomeScreen()
        }
        .tabItem {
          Label("首页", systemImage: "rectangle.grid.2x2.fill")
        }
        .tag(BangumiTab.home)

        NavigationStack {
          DiscoveryScreen()
        }
        .tabItem {
          Label("发现", systemImage: "sparkles")
        }
        .tag(BangumiTab.discovery)

        NavigationStack {
          RakuenScreen()
        }
        .tabItem {
          Label("Rakuen", systemImage: "bubble.left.and.bubble.right")
        }
        .tag(BangumiTab.rakuen)

        NavigationStack {
          MeScreen()
        }
        .tabItem {
          Label("我的", systemImage: "person.circle")
        }
        .tag(BangumiTab.me)
      }
    }
    .preferredColorScheme(settingsStore.preferredTheme.colorScheme)
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .tabBar)
    .sheet(isPresented: $model.isShowingSearch) {
      NavigationStack {
        SearchScreen()
      }
      .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingLogin) {
      NavigationStack {
        LoginScreen()
      }
      .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingNotifications) {
      NavigationStack {
        NotificationManagementScreen(showsDismissButton: true)
      }
    }
    .sheet(item: $model.presentedRoute) { route in
      NavigationStack {
        switch route {
        case let .subject(subjectID):
          SubjectDetailScreen(subjectID: subjectID)
        case let .user(userID):
          UserProfileScreen(userID: userID)
        case let .timeline(url):
          TimelineDetailScreen(url: url, fallbackTitle: "时间线详情")
        case let .rakuen(url):
          RakuenTopicScreen(topicURL: url, fallbackTitle: "Rakuen")
        case let .web(url, title):
          WebFallbackScreen(title: title, subtitle: nil, url: url)
        }
      }
      .environmentObject(model)
    }
    .fullScreenCover(item: $model.presentedImage) { item in
      BangumiImagePreviewScreen(imageURL: item.url)
    }
    .task {
      await notificationStore.prepareForAppLaunch()
    }
    .onChange(of: scenePhase) { newValue in
      Task {
        await notificationStore.handleScenePhase(newValue)
      }
    }
    .onChange(of: notificationStore.pendingOpenedSubjectID) { subjectID in
      guard let subjectID else { return }
      model.presentedRoute = .subject(subjectID)
      notificationStore.consumePendingOpenedSubjectID()
    }
  }
}

private struct BangumiCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(BangumiDesign.cardPadding)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: BangumiDesign.cardRadius))
  }
}

private extension View {
  func bangumiCardStyle() -> some View {
    modifier(BangumiCardModifier())
  }

  func bangumiRootScrollableLayout() -> some View {
    listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color(uiColor: .systemGroupedBackground))
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Color.clear
          .frame(height: BangumiDesign.rootTabBarClearance)
      }
  }
}

private struct BangumiRichText: View {
  let html: String
  private let baseURL = URL(string: "https://bgm.tv")!
  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    let quotes = BangumiHTMLParser.quoteBlocks(in: html)
    let imageURLs = Array(BangumiHTMLParser.imageURLs(in: html, baseURL: baseURL).prefix(4))

    VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
      if let attributed = BangumiHTMLParser.attributedString(from: html, baseURL: baseURL),
         !attributed.characters.isEmpty {
        Text(attributed)
          .tint(.accentColor)
      } else {
        Text(BangumiHTMLParser.stripTags(html))
      }

      if !quotes.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(quotes, id: \.self) { quote in
            HStack(alignment: .top, spacing: BangumiDesign.sectionSpacing) {
              RoundedRectangle(cornerRadius: 999)
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 4)

              Text(quote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(BangumiDesign.cardPadding)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
          }
        }
      }

      if !imageURLs.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(imageURLs, id: \.absoluteString) { imageURL in
            Button {
              model.presentImage(imageURL)
            } label: {
              AsyncImage(url: imageURL) { image in
                image
                  .resizable()
                  .scaledToFill()
              } placeholder: {
                RoundedRectangle(cornerRadius: 14)
                  .fill(Color.secondary.opacity(0.12))
                  .overlay {
                    ProgressView()
                  }
              }
              .frame(maxWidth: .infinity)
              .frame(height: 180)
              .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看图片")
          }
        }
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      model.present(url: url)
      return .handled
    })
  }
}

private struct BangumiImagePreviewScreen: View {
  let imageURL: URL

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()

      AsyncImage(url: imageURL) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
      } placeholder: {
        ProgressView()
          .tint(.white)
      }

      Button("关闭", systemImage: "xmark.circle.fill") {
        dismiss()
      }
      .labelStyle(.iconOnly)
      .font(.title2)
      .padding()
      .tint(.white)
    }
  }
}

private struct UserNameButton: View {
  let title: String
  let userID: String?
  var font: Font = .headline

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    Group {
      if let userID, !userID.isEmpty {
        Button(title) {
          model.present(url: URL(string: "https://bgm.tv/user/\(userID)")!)
        }
        .buttonStyle(.plain)
      } else {
        Text(title)
      }
    }
    .font(font)
    .foregroundStyle(.primary)
  }
}

private enum BangumiNavigationBarStyle {
  case solid
  case discoveryNative
  case hidden
}

private struct ScreenScaffold<Content: View>: View {
  let title: String
  let subtitle: String?
  let navigationBarStyle: BangumiNavigationBarStyle
  let showsNavigationTitle: Bool
  let content: Content

  @EnvironmentObject private var model: BangumiAppModel

  init(
    title: String,
    subtitle: String? = nil,
    navigationBarStyle: BangumiNavigationBarStyle = .solid,
    showsNavigationTitle: Bool = true,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.navigationBarStyle = navigationBarStyle
    self.showsNavigationTitle = showsNavigationTitle
    self.content = content()
  }

  var body: some View {
    let scaffold = ZStack {
      Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()

      content
    }

    switch navigationBarStyle {
    case .solid:
      if showsNavigationTitle {
        scaffold
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)

              Button("搜索", systemImage: "magnifyingglass") {
                model.isShowingSearch = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
      } else {
        scaffold
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)

              Button("搜索", systemImage: "magnifyingglass") {
                model.isShowingSearch = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
      }
    case .discoveryNative:
      if showsNavigationTitle {
        scaffold
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)

              Button("搜索", systemImage: "magnifyingglass") {
                model.isShowingSearch = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.hidden, for: .navigationBar)
      } else {
        scaffold
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)

              Button("搜索", systemImage: "magnifyingglass") {
                model.isShowingSearch = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.hidden, for: .navigationBar)
      }
    case .hidden:
      scaffold
        .toolbar(.hidden, for: .navigationBar)
    }
  }
}

private struct UserProfileScreen: View {
  let userID: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = UserProfileViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.profile == nil {
        ProgressView("加载中...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage, viewModel.profile == nil {
        UnavailableStateView(
          title: userID,
          systemImage: "person.crop.circle.badge.exclamationmark",
          message: error
        )
      } else {
        List {
          if let profile = viewModel.profile {
            Section {
              VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                  CoverImage(url: profile.avatarURL)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: BangumiDesign.heroRadius, style: .continuous))
                    .accessibilityHidden(true)

                  VStack(alignment: .leading, spacing: 6) {
                    Text(profile.displayName)
                      .font(.title3.weight(.semibold))

                    Text("@\(profile.username)")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)

                    if let sign = profile.sign, !sign.isEmpty {
                      Text(sign)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                  }
                }

                if let bio = profile.bio, !bio.isEmpty {
                  Text(bio)
                    .font(.body)
                }

                HStack(spacing: 16) {
                  if let location = profile.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                  }
                  if let joinedAt = profile.joinedAt, !joinedAt.isEmpty {
                    Label(joinedAt, systemImage: "calendar")
                  }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .bangumiCardStyle()
              .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
              .listRowBackground(Color.clear)
            }

            if !viewModel.collections.isEmpty {
              Section("在看动画") {
                ForEach(viewModel.collections) { item in
                  NavigationLink {
                    SubjectDetailScreen(subjectID: item.subjectID)
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(item.subject.nameCN ?? item.subject.name)
                      if let epStatus = item.epStatus {
                        Text("已追到第 \(epStatus) 集")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                    }
                  }
                }
              }
            } else if viewModel.profile != nil {
              Section("在看动画") {
                Text("当前没有读取到公开的在看动画，稍后可以通过 Safari 查看原站页面。")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .refreshable {
          await viewModel.refresh(using: model.userRepository, userID: userID)
        }
      }
    }
    .navigationTitle(viewModel.profile?.displayName ?? userID)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Link(destination: URL(string: "https://bgm.tv/user/\(userID)")!) {
          Label("在 Safari 中打开", systemImage: "safari")
            .labelStyle(.iconOnly)
        }
      }
    }
    .task {
      await viewModel.load(using: model.userRepository, userID: userID)
    }
  }
}

private final class UserProfileViewModel: ObservableObject {
  @Published var profile: BangumiUserProfile?
  @Published var collections: [BangumiCollectionItem] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var loadedUserID: String?

  @MainActor
  func load(using repository: UserRepository, userID: String) async {
    if loadedUserID == userID, profile != nil { return }
    await refresh(using: repository, userID: userID)
  }

  @MainActor
  func refresh(using repository: UserRepository, userID: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let profileTask = repository.fetchUserProfile(userID: userID)
      async let collectionsTask = repository.fetchWatchingCollections(userID: userID)
      profile = try await profileTask
      collections = (try? await collectionsTask) ?? []
      loadedUserID = userID
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct HomeCollectionsSection: Identifiable {
  let category: HomeCategory
  let items: [BangumiCollectionItem]

  var id: String { category.rawValue }
}

private struct HomeScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @StateObject private var viewModel = HomeViewModel()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color.accentColor.opacity(0.12),
          Color(uiColor: .systemGroupedBackground),
          Color(uiColor: .secondarySystemGroupedBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HomeHeader(
            isAuthenticated: sessionStore.isAuthenticated,
            currentUser: sessionStore.currentUser,
            onProfile: {
              model.activeTab = .me
            },
            onLogin: {
              model.isShowingLogin = true
            }
          )

          HomeCategoryBar(selection: $viewModel.selectedCategory)

          if let error = viewModel.errorMessage {
            SubjectInlineMessageCard(message: error)
          }

          if sessionStore.isAuthenticated {
            authenticatedContent
          } else {
            guestContent
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
      }
      .refreshable {
        await viewModel.refresh(
          using: model.userRepository,
          discoveryRepository: model.discoveryRepository,
          isAuthenticated: sessionStore.isAuthenticated
        )
      }
    }
    .task(id: sessionStore.isAuthenticated) {
      await viewModel.load(
        using: model.userRepository,
        discoveryRepository: model.discoveryRepository,
        isAuthenticated: sessionStore.isAuthenticated
      )
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button("通知", systemImage: "bell.badge") {
          model.isShowingNotifications = true
        }
        .labelStyle(.iconOnly)

        Button("搜索", systemImage: "magnifyingglass") {
          model.isShowingSearch = true
        }
        .labelStyle(.iconOnly)
      }
    }
    .toolbarBackground(.hidden, for: .navigationBar)
  }

  @ViewBuilder
  private var authenticatedContent: some View {
    if viewModel.isLoading && viewModel.totalCollectionCount == 0 {
      ProgressView("正在加载首页...")
        .frame(maxWidth: .infinity, minHeight: 280)
    } else if viewModel.totalCollectionCount == 0 {
      UnavailableStateView(
        title: "首页",
        systemImage: "square.stack.3d.up.slash",
        message: "暂时没有读取到在看中的收藏，可以稍后刷新，或先去发现页逛逛。"
      )
    } else {
      if viewModel.selectedCategory == .all {
        ForEach(viewModel.sectionsForAll) { section in
          HomeCollectionSectionView(
            title: section.category.title,
            subtitle: section.category == .anime ? "继续追番" : "最近更新",
            items: section.items
          )
        }
      } else {
        let items = viewModel.collections(for: viewModel.selectedCategory)
        if items.isEmpty {
          UnavailableStateView(
            title: viewModel.selectedCategory.title,
            systemImage: "tray",
            message: "当前分类下没有在看中的条目。"
          )
        } else {
          HomeCollectionSectionView(
            title: viewModel.selectedCategory.title,
            subtitle: "根据你的收藏进度整理",
            items: items
          )
        }
      }
    }
  }

  @ViewBuilder
  private var guestContent: some View {
    HomeGuestHeroCard {
      model.isShowingLogin = true
    }

    if viewModel.isLoading && viewModel.guestDays.isEmpty {
      ProgressView("正在加载首页...")
        .frame(maxWidth: .infinity, minHeight: 220)
    } else if viewModel.selectedCategory == .book || viewModel.selectedCategory == .real || viewModel.selectedCategory == .game {
      UnavailableStateView(
        title: viewModel.selectedCategory.title,
        systemImage: "person.crop.circle.badge.plus",
        message: "登录后可查看你的\(viewModel.selectedCategory.title)进度。"
      )
    } else if viewModel.guestDays.isEmpty {
      UnavailableStateView(
        title: "首页",
        systemImage: "sparkles",
        message: "暂时没有读取到推荐内容，可以稍后刷新。"
      )
    } else {
      ForEach(viewModel.displayedGuestDays) { day in
        HomeGuestSectionView(day: day)
      }
    }
  }
}

private final class HomeViewModel: ObservableObject {
  @Published var selectedCategory: HomeCategory = .all
  @Published var animeCollections: [BangumiCollectionItem] = []
  @Published var bookCollections: [BangumiCollectionItem] = []
  @Published var realCollections: [BangumiCollectionItem] = []
  @Published var gameCollections: [BangumiCollectionItem] = []
  @Published var guestDays: [BangumiCalendarDay] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var hasLoadedForAuthState: Bool?

  var totalCollectionCount: Int {
    collections(for: .all).count
  }

  var sectionsForAll: [HomeCollectionsSection] {
    [
      HomeCollectionsSection(category: .anime, items: animeCollections),
      HomeCollectionsSection(category: .book, items: bookCollections),
      HomeCollectionsSection(category: .real, items: realCollections),
      HomeCollectionsSection(category: .game, items: gameCollections)
    ]
    .filter { !$0.items.isEmpty }
  }

  var displayedGuestDays: [BangumiCalendarDay] {
    Array(guestDays.prefix(3))
  }

  func collections(for category: HomeCategory) -> [BangumiCollectionItem] {
    switch category {
    case .anime:
      animeCollections
    case .book:
      bookCollections
    case .real:
      realCollections
    case .game:
      gameCollections
    case .all:
      sortCollections(animeCollections + bookCollections + realCollections + gameCollections)
    }
  }

  @MainActor
  func load(
    using repository: UserRepository,
    discoveryRepository: DiscoveryRepository,
    isAuthenticated: Bool
  ) async {
    if hasLoadedForAuthState == isAuthenticated {
      let hasData = isAuthenticated ? totalCollectionCount > 0 : !guestDays.isEmpty
      if hasData { return }
    }
    await refresh(using: repository, discoveryRepository: discoveryRepository, isAuthenticated: isAuthenticated)
  }

  @MainActor
  func refresh(
    using repository: UserRepository,
    discoveryRepository: DiscoveryRepository,
    isAuthenticated: Bool
  ) async {
    isLoading = true
    defer { isLoading = false }

    if isAuthenticated {
      do {
        async let anime = repository.fetchWatchingCollections(subjectType: .anime, limit: 24)
        async let book = repository.fetchWatchingCollections(subjectType: .book, limit: 24)
        async let real = repository.fetchWatchingCollections(subjectType: .real, limit: 24)
        async let game = repository.fetchWatchingCollections(subjectType: .game, limit: 24)

        animeCollections = sortCollections((try? await anime) ?? [])
        bookCollections = sortCollections((try? await book) ?? [])
        realCollections = sortCollections((try? await real) ?? [])
        gameCollections = sortCollections((try? await game) ?? [])
        guestDays = []
        errorMessage = totalCollectionCount == 0 ? "已切换到首页，但当前没有读取到可展示的在看条目。" : nil
      }
      guestDays = []
    } else {
      do {
        guestDays = try await discoveryRepository.fetchCalendar()
        animeCollections = []
        bookCollections = []
        realCollections = []
        gameCollections = []
        errorMessage = nil
      } catch {
        guestDays = []
        errorMessage = error.localizedDescription
      }
    }

    hasLoadedForAuthState = isAuthenticated
  }

  private func sortCollections(_ items: [BangumiCollectionItem]) -> [BangumiCollectionItem] {
    items.sorted { lhs, rhs in
      if (lhs.epStatus ?? 0) != (rhs.epStatus ?? 0) {
        return (lhs.epStatus ?? 0) > (rhs.epStatus ?? 0)
      }
      if parsedDate(lhs.updatedAt) != parsedDate(rhs.updatedAt) {
        return parsedDate(lhs.updatedAt) > parsedDate(rhs.updatedAt)
      }
      return (lhs.subject.nameCN ?? lhs.subject.name) < (rhs.subject.nameCN ?? rhs.subject.name)
    }
  }

  private func parsedDate(_ value: String?) -> Date {
    guard let value, !value.isEmpty else { return .distantPast }
    let isoFormatter = ISO8601DateFormatter()
    if let date = isoFormatter.date(from: value) {
      return date
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    return formatter.date(from: value) ?? .distantPast
  }
}

private struct HomeHeader: View {
  let isAuthenticated: Bool
  let currentUser: BangumiUser?
  let onProfile: () -> Void
  let onLogin: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Bangumi")
            .font(.system(size: 30, weight: .black, design: .rounded))

          Text(isAuthenticated ? "把在看、在读、在玩的进度重新排回首页。" : "游客模式下先看看每日放送和推荐条目。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 12)

        if let currentUser, isAuthenticated {
          Button(action: onProfile) {
            if let avatarURL = currentUser.avatar?.best {
              CoverImage(url: avatarURL)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
              Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("打开我的页面")
        } else {
          HomeHeaderIconButton(systemImage: "person.crop.circle.badge.plus", action: onLogin)
        }
      }

      if let currentUser, isAuthenticated {
        HStack(spacing: 10) {
          SubjectCapsuleLabel(title: currentUser.displayName, systemImage: "person.fill")
          SubjectCapsuleLabel(title: "进度首页", systemImage: "rectangle.grid.2x2")
        }
      }
    }
    .padding(20)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
  }
}

private struct HomeHeaderIconButton: View {
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button("操作", systemImage: systemImage, action: action)
      .labelStyle(.iconOnly)
      .font(.system(size: 20, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
  }
}

private struct HomeCategoryBar: View {
  @Binding var selection: HomeCategory

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(HomeCategory.allCases) { category in
          Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
              selection = category
            }
          } label: {
            Text(category.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(selection == category ? Color.white : Color.primary)
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(
                Group {
                  if selection == category {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .fill(Color.accentColor)
                  } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .fill(Color.white.opacity(0.65))
                  }
                }
              )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 2)
    }
  }
}

private struct HomeGuestHeroCard: View {
  let onLogin: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("游客首页")
        .font(.title3.weight(.bold))

      Text("先看每日放送和条目推荐，登录后这里会变成你的进度首页。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button(action: onLogin) {
        Label("登录 Bangumi", systemImage: "person.crop.circle.badge.plus")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(
      LinearGradient(
        colors: [Color.accentColor.opacity(0.18), Color.orange.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
  }
}

private struct HomeCollectionSectionView: View {
  let title: String
  let subtitle: String
  let items: [BangumiCollectionItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HomeSectionHeader(title: title, subtitle: subtitle, count: items.count)

      if #available(iOS 17.0, *) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(items) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.subjectID)
              } label: {
                HomeSubjectCard(item: item, layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .contentMargins(.horizontal, BangumiDesign.screenHorizontalPadding, for: .scrollContent)
        .scrollClipDisabled()
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(items) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.subjectID)
              } label: {
                HomeSubjectCard(item: item, layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, BangumiDesign.screenHorizontalPadding)
        }
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      }
    }
  }
}

private struct HomeGuestSectionView: View {
  let day: BangumiCalendarDay

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HomeSectionHeader(title: day.weekday.cn, subtitle: "每日放送", count: min(day.items.count, 6))

      if #available(iOS 17.0, *) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(day.items.prefix(6)) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                HomeSubjectCard(summary: item, badgeTitle: "今日放送", layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .contentMargins(.horizontal, BangumiDesign.screenHorizontalPadding, for: .scrollContent)
        .scrollClipDisabled()
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(day.items.prefix(6)) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                HomeSubjectCard(summary: item, badgeTitle: "今日放送", layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, BangumiDesign.screenHorizontalPadding)
        }
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      }
    }
  }
}

private enum HomeSubjectCardLayout {
  case rail
  case compact

  var cardHeight: CGFloat {
    switch self {
    case .rail:
      196
    case .compact:
      356
    }
  }

  var titleBlockHeight: CGFloat {
    switch self {
    case .rail:
      60
    case .compact:
      76
    }
  }
}

private struct HomeSubjectCard: View {
  private let coverURL: URL?
  private let title: String
  private let subtitle: String?
  private let score: Double?
  private let rank: Int?
  private let progressTitle: String
  private let progressValue: String
  private let badgeTitle: String
  private let ctaTitle: String
  private let layout: HomeSubjectCardLayout

  init(item: BangumiCollectionItem, layout: HomeSubjectCardLayout = .rail) {
    coverURL = item.subject.images?.best
    title = item.subject.nameCN ?? item.subject.name
    subtitle = item.subject.nameCN != nil && item.subject.nameCN != item.subject.name ? item.subject.name : nil
    score = item.subject.score
    rank = item.subject.rank
    badgeTitle = SubjectType.title(for: item.subjectType)
    ctaTitle = item.subjectType == SubjectType.anime.rawValue ? "继续追番" : "查看详情"
    self.layout = layout

    switch item.subjectType {
    case SubjectType.anime.rawValue:
      progressTitle = "追番进度"
      let total = item.subject.totalEpisodes ?? item.subject.eps ?? 0
      if total > 0 {
        progressValue = "\(item.epStatus ?? 0)/\(total) 集"
      } else {
        progressValue = "已看到第 \(item.epStatus ?? 0) 集"
      }
    case SubjectType.book.rawValue:
      progressTitle = "阅读进度"
      if let volStatus = item.volStatus, volStatus > 0 {
        progressValue = "卷 \(volStatus)"
      } else {
        progressValue = "打开书籍详情"
      }
    case SubjectType.game.rawValue:
      progressTitle = "游戏进度"
      progressValue = "继续记录"
    case SubjectType.real.rawValue:
      progressTitle = "观看进度"
      progressValue = "回到条目"
    default:
      progressTitle = "条目"
      progressValue = "查看详情"
    }
  }

  init(summary: BangumiSubjectSummary, badgeTitle: String, layout: HomeSubjectCardLayout = .rail) {
    coverURL = summary.images?.best
    title = summary.nameCN ?? summary.name
    subtitle = summary.nameCN != nil && summary.nameCN != summary.name ? summary.name : nil
    score = summary.rating?.score
    rank = summary.rating?.rank
    self.badgeTitle = badgeTitle
    ctaTitle = "查看详情"
    progressTitle = summary.date?.isEmpty == false ? "放送日期" : "条目"
    progressValue = summary.date ?? SubjectType.title(for: summary.type)
    self.layout = layout
  }

  var body: some View {
    Group {
      switch layout {
      case .rail:
        HStack(alignment: .top, spacing: 14) {
          CoverImage(url: coverURL)
            .frame(width: 88, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

          VStack(alignment: .leading, spacing: 10) {
            HomeSubjectCardMetaRow(badgeTitle: badgeTitle, rank: rank)
            HomeSubjectCardTitle(title: title, subtitle: subtitle, lineLimit: 2, layout: layout)
            HomeSubjectCardMetrics(score: score, progressTitle: progressTitle)
            Text(progressValue)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Spacer(minLength: 0)

            HStack {
              Spacer()
              HomeSubjectCardCTA(title: ctaTitle)
            }
          }
          .frame(maxHeight: .infinity, alignment: .top)
        }
      case .compact:
        VStack(alignment: .leading, spacing: 10) {
          CoverImage(url: coverURL)
            .frame(height: 138)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

          HomeSubjectCardMetaRow(badgeTitle: badgeTitle, rank: rank)
          HomeSubjectCardTitle(title: title, subtitle: subtitle, lineLimit: 2, layout: layout)
          HomeSubjectCardMetrics(score: score, progressTitle: progressTitle)

          Text(progressValue)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Spacer(minLength: 0)

          HStack {
            Spacer()
            HomeSubjectCardCTA(title: ctaTitle)
          }
        }
        .frame(maxHeight: .infinity, alignment: .top)
      }
    }
    .frame(height: layout.cardHeight, alignment: .top)
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

private struct HomeSectionHeader: View {
  let title: String
  let subtitle: String
  let count: Int

  var body: some View {
    HStack(alignment: .lastTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title3.weight(.bold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Text("\(count) 项")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.65), in: Capsule())
    }
  }
}

private struct HomeSubjectCardMetaRow: View {
  let badgeTitle: String
  let rank: Int?

  var body: some View {
    HStack {
      SubjectCapsuleLabel(title: badgeTitle, systemImage: "square.stack.fill")
      Spacer(minLength: 8)
      if let rank {
        Text("#\(rank)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct HomeSubjectCardTitle: View {
  let title: String
  let subtitle: String?
  let lineLimit: Int
  let layout: HomeSubjectCardLayout

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
        .lineLimit(lineLimit)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, minHeight: layout.titleBlockHeight, maxHeight: layout.titleBlockHeight, alignment: .topLeading)
  }
}

private struct HomeSubjectCardMetrics: View {
  let score: Double?
  let progressTitle: String

  var body: some View {
    HStack(spacing: 12) {
      if let score {
        Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
          .foregroundStyle(Color.orange)
      }
      Text(progressTitle)
        .foregroundStyle(.secondary)
    }
    .font(.caption)
  }
}

private struct HomeSubjectCardCTA: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption.weight(.bold))
      .foregroundStyle(Color.accentColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(Color.accentColor.opacity(0.12), in: Capsule())
  }
}

private struct TimelineScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = TimelineViewModel()

  var body: some View {
    ScreenScaffold(title: "时间线", subtitle: "V1 先接入全站只读列表，回复和复杂交互仍保留 Web 回退。") {
      Group {
        if viewModel.isLoading && viewModel.items.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
          UnavailableStateView(
            title: "时间线加载失败",
            systemImage: "clock.arrow.circlepath",
            message: error
          )
        } else {
          List {
            Section {
              Picker("类型", selection: $viewModel.filter) {
                ForEach(TimelineFilter.allCases) { filter in
                  Text(filter.title).tag(filter)
                }
              }
              .pickerStyle(.segmented)
            }

            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
              NavigationLink {
                timelineDestination(for: item)
              } label: {
                TimelineRow(item: item)
              }
              .task {
                await viewModel.loadMoreIfNeeded(
                  currentIndex: index,
                  using: model.timelineRepository
                )
              }
            }

            if viewModel.isLoadingMore {
              Section {
                HStack {
                  Spacer()
                  ProgressView("正在加载更多…")
                  Spacer()
                }
              }
            }
          }
          .refreshable {
            await viewModel.refresh(using: model.timelineRepository)
          }
          .bangumiRootScrollableLayout()
        }
      }
      .task {
        await viewModel.bootstrap(using: model.timelineRepository)
      }
      .onChange(of: viewModel.filter) { _ in
        Task {
          await viewModel.refresh(using: model.timelineRepository)
        }
      }
    }
  }

  @ViewBuilder
  private func timelineDestination(for item: BangumiTimelineItem) -> some View {
    if let subjectID = item.subjectID {
      SubjectDetailScreen(subjectID: subjectID)
    } else if let navigationURL = item.navigationURL {
      TimelineDetailScreen(url: navigationURL, fallbackTitle: item.targetTitle ?? "时间线详情")
    } else {
      WebFallbackScreen(
        title: item.targetTitle ?? "时间线详情",
        subtitle: item.summary,
        url: item.navigationURL
      )
    }
  }
}

private final class TimelineViewModel: ObservableObject {
  @Published var items: [BangumiTimelineItem] = []
  @Published var filter: TimelineFilter = .all
  @Published var isLoading = false
  @Published var isLoadingMore = false
  @Published var errorMessage: String?

  private var nextPage = 1
  private var hasBootstrapped = false

  @MainActor
  func bootstrap(using repository: TimelineRepository) async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    await refresh(using: repository)
  }

  @MainActor
  func refresh(using repository: TimelineRepository) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let page = try await repository.fetch(page: 1, filter: filter)
      items = page.items
      nextPage = page.nextPage ?? 1
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  func loadMoreIfNeeded(currentIndex: Int, using repository: TimelineRepository) async {
    guard !isLoading, !isLoadingMore else { return }
    guard currentIndex >= items.count - 4 else { return }
    guard nextPage > 1 else { return }

    isLoadingMore = true
    defer { isLoadingMore = false }

    do {
      let page = try await repository.fetch(page: nextPage, filter: filter)
      let existingIDs = Set(items.map(\.id))
      items.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
      nextPage = page.nextPage ?? nextPage
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct TimelineRow: View {
  let item: BangumiTimelineItem

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: item.avatarURL)
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        Text(item.summary)
          .font(.subheadline)
          .foregroundStyle(.primary)
          .lineLimit(3)

        if let comment = item.comment, !comment.isEmpty {
          Text(comment)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        if let firstImage = item.imageURLs.first {
          CoverImage(url: firstImage)
            .frame(width: 88, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        HStack(spacing: BangumiDesign.sectionSpacing) {
          if !item.date.isEmpty {
            Label(item.date, systemImage: "calendar")
          }
          if !item.time.isEmpty {
            Label(item.time, systemImage: "clock")
          }
          if let replyCount = item.replyCount {
            Label(replyCount, systemImage: "text.bubble")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct TimelineDetailScreen: View {
  let url: URL
  let fallbackTitle: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = TimelineDetailViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.detail == nil {
        ProgressView("加载中...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage, viewModel.detail == nil {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "clock.arrow.circlepath",
          message: error
        )
      } else if let detail = viewModel.detail, viewModel.hasRenderableContent {
        List {
          Section("动态") {
            TimelinePostCard(post: detail.main)
          }

          if detail.replies.isEmpty {
            Section("回复") {
              Text("当前没有解析到回复，仍可通过右上角 Safari 查看网页原文。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          } else {
            Section("回复 \(detail.replies.count)") {
              ForEach(detail.replies) { reply in
                TimelinePostCard(post: reply)
              }
            }
          }
        }
        .refreshable {
          await viewModel.refresh(using: model.timelineRepository, url: url)
        }
      } else {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "text.bubble",
          message: "暂时没有解析到动态内容，可以先用右上角 Safari 查看原文。"
        )
      }
    }
    .task(id: url.absoluteString) {
      await viewModel.load(using: model.timelineRepository, url: url)
    }
    .navigationTitle(viewModel.detail?.main.userName.isEmpty == false ? viewModel.detail?.main.userName ?? fallbackTitle : fallbackTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Link(destination: url) {
          Label("在 Safari 中打开", systemImage: "safari")
            .labelStyle(.iconOnly)
        }
      }
    }
  }
}

private final class TimelineDetailViewModel: ObservableObject {
  @Published var detail: BangumiTimelineDetail?
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var hasAttemptedLoad = false

  private var loadedURL: URL?

  var hasRenderableContent: Bool {
    guard let detail else { return false }
    let mainText = detail.main.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let mainHTML = detail.main.htmlText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !mainText.isEmpty || !mainHTML.isEmpty || !detail.replies.isEmpty
  }

  @MainActor
  func load(using repository: TimelineRepository, url: URL) async {
    if loadedURL == url, detail != nil { return }
    await refresh(using: repository, url: url)
  }

  @MainActor
  func refresh(using repository: TimelineRepository, url: URL) async {
    isLoading = true
    hasAttemptedLoad = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      detail = try await repository.fetchDetail(url: url)
      loadedURL = url
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct TimelinePostCard: View {
  let post: BangumiTimelinePost

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: post.avatarURL)
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        UserNameButton(title: post.userName, userID: post.userID)

        if let htmlText = post.htmlText, !htmlText.isEmpty {
          BangumiRichText(html: htmlText)
            .textSelection(.enabled)
        } else if !post.text.isEmpty {
          Text(post.text)
            .font(.body)
            .textSelection(.enabled)
        }

        if !post.date.isEmpty {
          Text(post.date)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct DiscoveryScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var viewModel = DiscoveryViewModel()
  @State private var heroSelection = 0
  @State private var heroAutoScrollPausedUntil: Date?
  @State private var isProgrammaticHeroSelectionChange = false
  @State private var heroFrame: CGRect = .zero

  private var featuredDay: BangumiCalendarDay? {
    let availableDays = viewModel.days.filter { !$0.items.isEmpty }
    guard !availableDays.isEmpty else { return nil }

    let calendar = Calendar(identifier: .gregorian)
    let weekday = calendar.component(.weekday, from: Date())
    let preferredNames = bangumiWeekdayNames(for: weekday)
    if let matchedByName = availableDays.first(where: { preferredNames.contains($0.weekday.cn) }) {
      return matchedByName
    }

    let preferredIDs = bangumiWeekdayIDs(for: weekday)
    if let matchedByID = availableDays.first(where: { preferredIDs.contains($0.weekday.id) }) {
      return matchedByID
    }

    return availableDays.first
  }

  private var featuredItems: [BangumiSubjectSummary] {
    featuredDay?.items ?? []
  }

  private var isHeroAutoScrollPaused: Bool {
    guard let heroAutoScrollPausedUntil else { return false }
    return heroAutoScrollPausedUntil > Date()
  }

  private var isHeroVisible: Bool {
    guard heroFrame != .zero else { return false }
    let screenBounds = UIScreen.main.bounds
    return heroFrame.maxY > 120 && heroFrame.minY < screenBounds.height - BangumiDesign.rootTabBarClearance
  }

  var body: some View {
    ScreenScaffold(
      title: "发现",
      navigationBarStyle: .discoveryNative,
      showsNavigationTitle: false
    ) {
      Group {
        if viewModel.isLoading && viewModel.days.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.days.isEmpty {
          UnavailableStateView(
            title: "加载失败",
            systemImage: "exclamationmark.triangle",
            message: error
          )
        } else {
          ZStack {
            LinearGradient(
              colors: [
                Color.accentColor.opacity(0.12),
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
              LazyVStack(alignment: .leading, spacing: BangumiDiscoveryDesign.screenSpacing) {
                if featuredDay != nil {
                  DiscoveryEditorialHeader()
                }

                if let featuredDay, !featuredItems.isEmpty {
                  if featuredItems.count == 1, let featuredItem = featuredItems.first {
                    NavigationLink {
                      SubjectDetailScreen(subjectID: featuredItem.id)
                    } label: {
                      DiscoveryHeroCard(day: featuredDay, item: featuredItem)
                    }
                    .buttonStyle(.plain)
                    .background(
                      GeometryReader { proxy in
                        Color.clear
                          .preference(key: DiscoveryHeroFramePreferenceKey.self, value: proxy.frame(in: .global))
                      }
                    )
                  } else {
                    DiscoveryHeroCarousel(
                      day: featuredDay,
                      items: featuredItems,
                      selection: $heroSelection
                    )
                  }
                }

                if let error = viewModel.errorMessage {
                  SubjectInlineMessageCard(message: error)
                }

                ForEach(viewModel.days.filter { !$0.items.isEmpty }) { day in
                  DiscoverySectionCard(day: day)
                }
              }
              .padding(.horizontal, 16)
              .padding(.top, 10)
              .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
            }
            .refreshable {
              await viewModel.load(using: model.discoveryRepository)
            }
            .onPreferenceChange(DiscoveryHeroFramePreferenceKey.self) { frame in
              heroFrame = frame
            }
          }
          .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
              .frame(height: BangumiDesign.rootTabBarClearance)
          }
        }
      }
      .task {
        await viewModel.load(using: model.discoveryRepository)
      }
      .task(id: featuredItems.map(\.id)) {
        guard featuredItems.count > 1 else { return }
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 4_800_000_000)
          guard !Task.isCancelled else { break }
          await MainActor.run {
            guard featuredItems.count > 1 else { return }
            guard scenePhase == .active else { return }
            guard isHeroVisible else { return }
            guard !isHeroAutoScrollPaused else { return }
            advanceHeroCarousel()
          }
        }
      }
      .onChange(of: featuredItems.map(\.id)) { ids in
        guard !ids.isEmpty else {
          heroSelection = 0
          return
        }
        heroSelection = min(heroSelection, ids.count - 1)
      }
      .onChange(of: heroSelection) { _ in
        guard featuredItems.count > 1 else { return }
        guard !isProgrammaticHeroSelectionChange else { return }
        pauseHeroAutoScroll()
      }
    }
  }

  private func advanceHeroCarousel() {
    guard featuredItems.count > 1 else { return }
    isProgrammaticHeroSelectionChange = true
    heroSelection = (heroSelection + 1) % featuredItems.count
    DispatchQueue.main.async {
      isProgrammaticHeroSelectionChange = false
    }
  }

  private func pauseHeroAutoScroll() {
    heroAutoScrollPausedUntil = Date().addingTimeInterval(6)
  }

  private func bangumiWeekdayNames(for systemWeekday: Int) -> [String] {
    switch systemWeekday {
    case 1:
      ["星期日", "星期天", "周日", "周天"]
    case 2:
      ["星期一", "周一"]
    case 3:
      ["星期二", "周二"]
    case 4:
      ["星期三", "周三"]
    case 5:
      ["星期四", "周四"]
    case 6:
      ["星期五", "周五"]
    case 7:
      ["星期六", "周六"]
    default:
      []
    }
  }

  private func bangumiWeekdayIDs(for systemWeekday: Int) -> [Int] {
    let mondayFirst = ((systemWeekday + 5) % 7) + 1
    return [mondayFirst, systemWeekday]
  }
}

private struct DiscoveryHeroFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

private struct DiscoveryTopBar: View {
  let onNotifications: () -> Void
  let onSearch: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button("通知", systemImage: "bell") {
        onNotifications()
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 52, height: 52)

      Divider()
        .frame(height: 24)

      Button("搜索", systemImage: "magnifyingglass") {
        onSearch()
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 52, height: 52)
    }
    .background(.thinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(Color.white.opacity(0.38), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
  }
}

private struct DiscoveryEditorialHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(BangumiDiscoveryCopy.heroEyebrow)
        .font(.caption.weight(.bold))
        .tracking(1.3)
        .foregroundStyle(.secondary)

      Text(BangumiDiscoveryCopy.heroTitle)
        .font(.system(size: 32, weight: .black, design: .rounded))
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct DiscoveryHeroCarousel: View {
  let day: BangumiCalendarDay
  let items: [BangumiSubjectSummary]
  @Binding var selection: Int
  @State private var scrollTargetID: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if #available(iOS 17.0, *) {
        modernCarousel
      } else {
        legacyCarousel
      }

      HStack(spacing: 10) {
        HStack(spacing: 7) {
          ForEach(Array(items.indices), id: \.self) { index in
            Capsule()
              .fill(index == selection ? Color.primary : Color.primary.opacity(0.18))
              .frame(width: index == selection ? 18 : 7, height: 7)
          }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: selection)

        Spacer(minLength: 12)

        Text("\(selection + 1) / \(items.count)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 6)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("今日主打轮播，第 \(selection + 1) 页，共 \(items.count) 页")
    }
  }

  @available(iOS 17.0, *)
  private var modernCarousel: some View {
    GeometryReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: BangumiDiscoveryDesign.cardSpacing) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            NavigationLink {
              SubjectDetailScreen(subjectID: item.id)
            } label: {
              DiscoveryHeroCard(day: day, item: item)
            }
            .buttonStyle(.plain)
            .frame(
              width: max(
                proxy.size.width,
                1
              )
            )
            .id(index)
          }
        }
        .scrollTargetLayout()
      }
      .contentMargins(.horizontal, BangumiDiscoveryDesign.heroPageInset, for: .scrollContent)
      .scrollClipDisabled()
      .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
      .scrollPosition(id: $scrollTargetID)
      .background(
        GeometryReader { scrollProxy in
          Color.clear
            .preference(key: DiscoveryHeroFramePreferenceKey.self, value: scrollProxy.frame(in: .global))
        }
      )
      .onAppear {
        scrollTargetID = selection
      }
      .onChange(of: selection) { newValue in
        guard scrollTargetID != newValue else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
          scrollTargetID = newValue
        }
      }
      .onChange(of: scrollTargetID) { newValue in
        guard let newValue, selection != newValue else { return }
        selection = newValue
      }
    }
    .frame(height: BangumiDiscoveryDesign.heroHeight)
  }

  private var legacyCarousel: some View {
    TabView(selection: $selection) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        NavigationLink {
          SubjectDetailScreen(subjectID: item.id)
        } label: {
          DiscoveryHeroCard(day: day, item: item)
            .padding(.horizontal, BangumiDiscoveryDesign.heroPageInset)
        }
        .buttonStyle(.plain)
        .tag(index)
      }
    }
    .frame(height: BangumiDiscoveryDesign.heroHeight)
    .tabViewStyle(.page(indexDisplayMode: .never))
    .background(
      GeometryReader { proxy in
        Color.clear
          .preference(key: DiscoveryHeroFramePreferenceKey.self, value: proxy.frame(in: .global))
      }
    )
  }
}

private struct DiscoveryHeroCard: View {
  let day: BangumiCalendarDay
  let item: BangumiSubjectSummary

  private var title: String {
    item.nameCN ?? item.name
  }

  private var subtitle: String? {
    guard let localized = item.nameCN, localized != item.name else {
      return nil
    }
    return item.name
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      CoverImage(url: item.images?.best)
        .frame(maxWidth: .infinity)
        .frame(height: BangumiDiscoveryDesign.heroHeight)

      LinearGradient(
        colors: [
          Color.black.opacity(0.04),
          Color.black.opacity(0.2),
          Color.black.opacity(0.78),
          Color.black.opacity(0.94)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      VStack(alignment: .leading, spacing: 14) {
        Spacer(minLength: 24)

        HStack(spacing: 8) {
          DiscoveryBadge(title: day.weekday.cn, systemImage: "calendar")

          if let date = item.date, !date.isEmpty {
            DiscoveryBadge(title: date, systemImage: "clock")
          }

          if let score = item.rating?.score {
            DiscoveryBadge(
              title: score.formatted(.number.precision(.fractionLength(1))),
              systemImage: "star.fill"
            )
          }
        }

        Text(title)
          .font(.system(size: 34, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.headline)
            .foregroundStyle(Color.white.opacity(0.86))
            .lineLimit(2)
        }
      }
      .padding(22)
    }
    .clipShape(RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.heroRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.heroRadius, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title)，\(day.weekday.cn)主打")
  }
}

private struct DiscoverySectionCard: View {
  let day: BangumiCalendarDay

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(BangumiDiscoveryCopy.sectionEyebrow)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)

          Text(day.weekday.cn)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(.primary)

          Text(BangumiDiscoveryCopy.sectionSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Text("\(day.items.count) 部")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.white.opacity(0.58), in: Capsule())
      }

      VStack(spacing: 12) {
        ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
          NavigationLink {
            SubjectDetailScreen(subjectID: item.id)
          } label: {
            DiscoveryRowCard(item: item)
          }
          .buttonStyle(.plain)

          if index != day.items.count - 1 {
            Divider()
              .padding(.horizontal, 6)
          }
        }
      }
    }
    .padding(BangumiDiscoveryDesign.sectionPadding)
    .background(
      LinearGradient(
        colors: [
          Color(uiColor: .secondarySystemGroupedBackground),
          Color(uiColor: .systemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.sectionRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.sectionRadius, style: .continuous)
        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
    }
  }
}

private struct DiscoveryRowCard: View {
  let item: BangumiSubjectSummary

  private var title: String {
    item.nameCN ?? item.name
  }

  private var subtitle: String? {
    guard let localized = item.nameCN, localized != item.name else {
      return nil
    }
    return item.name
  }

  private var episodeText: String? {
    let total = item.totalEpisodes ?? item.eps
    guard let total, total > 0 else {
      return nil
    }
    return "\(total) 集"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CoverImage(url: item.images?.best)
        .frame(width: BangumiDiscoveryDesign.rowCoverWidth, height: BangumiDiscoveryDesign.rowCoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          if let score = item.rating?.score {
            Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
              .foregroundStyle(Color.orange)
          }

          if let episodeText {
            Label(episodeText, systemImage: "play.tv")
              .foregroundStyle(.secondary)
          }
        }
        .font(.caption.weight(.semibold))

        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        HStack(spacing: 10) {
          if let date = item.date, !date.isEmpty {
            Label(date, systemImage: "calendar")
              .foregroundStyle(.secondary)
          } else {
            Label(SubjectType.title(for: item.type), systemImage: "square.stack")
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          Text("查看详情")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)
        }
        .font(.caption)
      }

      Spacer(minLength: 10)

      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
    }
    .padding(BangumiDiscoveryDesign.rowPadding)
    .background(
      Color(uiColor: .tertiarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.rowRadius, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
  }
}

private struct DiscoveryBadge: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.16), in: Capsule())
  }
}

private final class DiscoveryViewModel: ObservableObject {
  @Published var days: [BangumiCalendarDay] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  @MainActor
  func load(using repository: DiscoveryRepository) async {
    isLoading = true
    defer { isLoading = false }

    do {
      days = try await repository.fetchCalendar()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct SearchScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel = SearchViewModel()

  var body: some View {
    List {
      Section {
        Picker("类型", selection: $viewModel.subjectType) {
          ForEach(SubjectType.allCases) { type in
            Text(type.title).tag(type)
          }
        }
        .pickerStyle(.menu)

        Toggle(
          "模糊搜索",
          isOn: Binding(
            get: { viewModel.matchMode.isFuzzy },
            set: { isOn in
              let nextMode: BangumiSearchMatchMode = isOn ? .fuzzy : .precise
              guard nextMode != viewModel.matchMode else { return }
              viewModel.matchMode = nextMode
            }
          )
        )

        Button("查询", action: submitSearch)
          .disabled(viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if !settingsStore.recentSearches.isEmpty {
        Section("最近搜索") {
          ForEach(settingsStore.recentSearches, id: \.self) { item in
            Button(item) {
              viewModel.keyword = item
              submitSearch()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button("删除", role: .destructive) {
                settingsStore.removeSearch(item)
              }
            }
          }

          Button("清除历史", role: .destructive) {
            settingsStore.clearSearches()
          }
        }
      }

      if viewModel.isLoading {
        Section {
          ProgressView(viewModel.lastSubmittedKeyword.isEmpty ? "正在搜索..." : "正在搜索 “\(viewModel.lastSubmittedKeyword)” …")
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
      else if let error = viewModel.errorMessage, viewModel.hasSearched {
        Section("错误") {
          Text(error)
            .foregroundStyle(.red)
          Button("重试", action: submitSearch)
        }
      }
      else if viewModel.hasSearched {
        Section("结果") {
          if viewModel.results.isEmpty {
            UnavailableStateView(
              title: "没有找到匹配条目",
              systemImage: "magnifyingglass",
              message: "换个关键词、切换类型，或试试打开模糊搜索。"
            )
            .frame(maxWidth: .infinity, minHeight: 180)
            .listRowBackground(Color.clear)
          } else {
            ForEach(viewModel.results) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  SubjectRow(item: item)

                  if let searchMeta = item.searchMeta, !searchMeta.isEmpty {
                    Text(searchMeta)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                      .padding(.leading, 68)
                  }
                }
                .padding(.vertical, 4)
              }
            }
          }
        }
      }
      else if settingsStore.recentSearches.isEmpty {
        Section {
          UnavailableStateView(
            title: "开始搜索",
            systemImage: "magnifyingglass",
            message: "先选类型，输入关键词，再决定要不要打开模糊搜索。"
          )
          .frame(maxWidth: .infinity, minHeight: 180)
          .listRowBackground(Color.clear)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("搜索")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(
      text: $viewModel.keyword,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "输入关键字"
    )
    .onSubmit(of: .search, submitSearch)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.backward")
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if let latest = settingsStore.recentSearches.first, viewModel.keyword.isEmpty {
            Button("恢复最近一次输入") {
              viewModel.keyword = latest
            }
          }

          if !viewModel.keyword.isEmpty {
            Button("清空输入") {
              viewModel.clearKeyword()
            }
          }

          if !settingsStore.recentSearches.isEmpty {
            Button("清空搜索历史", role: .destructive) {
              settingsStore.clearSearches()
            }
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }
    }
    .searchSuggestions {
      ForEach(settingsStore.recentSearches.prefix(5), id: \.self) { item in
        Button(item) {
          viewModel.keyword = item
          submitSearch()
        }
        .searchCompletion(item)
      }
    }
    .onChange(of: viewModel.matchMode) { _ in
      guard viewModel.hasSearched else { return }
      submitSearch()
    }
  }

  private func submitSearch() {
    Task {
      await viewModel.search(using: model.searchRepository, settings: settingsStore)
    }
  }
}

private final class SearchViewModel: ObservableObject {
  @Published var keyword = ""
  @Published var subjectType: SubjectType = .anime
  @Published var matchMode: BangumiSearchMatchMode = .precise
  @Published var results: [BangumiSubjectSummary] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published private(set) var hasSearched = false
  @Published private(set) var lastSubmittedKeyword = ""

  func toggleMatchMode() {
    matchMode = matchMode == .precise ? .fuzzy : .precise
  }

  func clearKeyword() {
    keyword = ""
  }

  func resetResultsIfNeeded() {
    guard keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    results = []
    errorMessage = nil
    hasSearched = false
    lastSubmittedKeyword = ""
  }

  @MainActor
  func search(using repository: SearchRepository, settings: BangumiSettingsStore) async {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    isLoading = true
    errorMessage = nil
    hasSearched = true
    lastSubmittedKeyword = trimmed
    defer { isLoading = false }

    do {
      results = try await repository.search(
        query: BangumiSearchQuery(
          keyword: trimmed,
          type: subjectType,
          matchMode: matchMode
        )
      )
      settings.rememberSearch(trimmed)
      errorMessage = results.isEmpty ? "没有找到匹配条目。" : nil
    } catch {
      results = []
      errorMessage = error.localizedDescription
    }
  }
}

private enum SubjectDetailContentTab: String, CaseIterable, Identifiable {
  case overview
  case details

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: "简介"
    case .details: "详情"
    }
  }
}

private struct SubjectDetailScreen: View {
  let subjectID: Int

  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @StateObject private var viewModel = SubjectDetailViewModel()
  @State private var isShowingEditor = false
  @State private var isShowingFullSummary = false
  @State private var isShowingAllTags = false
  @State private var selectedContentTab: SubjectDetailContentTab = .overview

  var body: some View {
    ScreenScaffold(
      title: viewModel.navigationTitle,
      subtitle: nil,
      navigationBarStyle: .discoveryNative
    ) {
      Group {
        if viewModel.isLoading && viewModel.subject == nil {
          ProgressView("正在加载条目...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.subject == nil {
          UnavailableStateView(
            title: "条目详情",
            systemImage: "exclamationmark.triangle",
            message: error
          )
        } else if let subject = viewModel.subject {
          let notificationSubscription = notificationStore.subscription(for: subjectID)
          let presentation = viewModel.presentation

          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              SubjectHeroCard(
                subject: subject,
                collectionTitle: viewModel.collection.map { viewModel.collectionTitle(from: $0) },
                watchedEpisodes: viewModel.watchedEpisodes
              )

              if let error = viewModel.errorMessage {
                SubjectInlineMessageCard(message: error)
              }

              SubjectActionCard(
                subjectType: subject.type,
                isAuthenticated: sessionStore.isAuthenticated,
                collectionTitle: viewModel.collection.map { viewModel.collectionTitle(from: $0) },
                progressValue: subject.type == SubjectType.book.rawValue ? (viewModel.collection?.volStatus ?? 0) : viewModel.watchedEpisodes,
                totalProgress: subject.type == SubjectType.book.rawValue ? (subject.volumes ?? 0) : max(viewModel.episodes.count, subject.totalEpisodes ?? subject.eps ?? 0),
                notificationPermissionState: notificationStore.permissionState,
                notificationSubscription: notificationSubscription,
                isNotificationUpdating: notificationStore.updatingSubjectIDs.contains(subjectID),
                onEditCollection: {
                  isShowingEditor = true
                },
                onToggleNotifications: {
                  Task {
                    await notificationStore.toggleSubscription(subject: subject, episodes: viewModel.episodes)
                  }
                }
              )

              if !viewModel.episodes.isEmpty {
                SubjectEpisodeProgressSection(
                  episodes: viewModel.episodes,
                  statuses: viewModel.episodeStatuses,
                  watchedEpisodes: viewModel.watchedEpisodes,
                  isAuthenticated: sessionStore.isAuthenticated,
                  updatingEpisodeID: viewModel.updatingEpisodeID,
                  onSelectStatus: { episode, status in
                    Task {
                      _ = await viewModel.updateEpisodeStatus(
                        using: model.subjectRepository,
                        subjectID: subjectID,
                        episode: episode,
                        status: status,
                        isAuthenticated: sessionStore.isAuthenticated
                      )
                    }
                  }
                )
              }

              SubjectDetailTabBar(selection: $selectedContentTab)

              switch selectedContentTab {
              case .overview:
                if let summary = subject.summary, !summary.isEmpty {
                  SubjectSummarySection(
                    summary: summary,
                    isExpanded: $isShowingFullSummary
                  )
                }

                if !presentation.previews.isEmpty {
                  SubjectPreviewSection(items: presentation.previews, moreURL: presentation.morePreviewsURL)
                }

                if let tags = subject.tags, !tags.isEmpty {
                  SubjectTagsSection(
                    tags: tags,
                    isExpanded: $isShowingAllTags
                  )
                }

                SubjectCommentsSection(
                  comments: viewModel.comments,
                  isLoading: viewModel.isLoadingComments,
                  errorMessage: viewModel.commentsErrorMessage,
                  moreURL: URL(string: "https://bgm.tv/subject/\(subjectID)/comments")
                )

              case .details:
                if viewModel.isLoadingPresentation {
                  SubjectDetailLoadingSection()
                } else if !presentation.infoEntries.isEmpty {
                  SubjectDetailInfoSection(entries: presentation.infoEntries)
                } else {
                  SubjectInfoGridCard(subject: subject)
                }

                if let ratingBreakdown = presentation.ratingBreakdown ?? SubjectRatingSection.fallbackBreakdown(from: subject) {
                  SubjectRatingSection(
                    breakdown: ratingBreakdown,
                    moreURL: presentation.statsURL
                  )
                }

                if let collection = subject.collection {
                  SubjectCollectionStatsSection(stats: collection)
                }

                if !presentation.cast.isEmpty {
                  SubjectCastSection(items: presentation.cast, moreURL: presentation.moreCastURL)
                }

                if !presentation.staff.isEmpty {
                  SubjectStaffSection(items: presentation.staff, moreURL: presentation.moreStaffURL)
                }

                if !presentation.relations.isEmpty {
                  SubjectRelationSection(items: presentation.relations, moreURL: presentation.moreRelationsURL)
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
          }
          .refreshable {
            await viewModel.load(
              subjectID: subjectID,
              repository: model.subjectRepository,
              isAuthenticated: sessionStore.isAuthenticated
            )
          }
        }
      }
    }
    .task {
      await viewModel.load(subjectID: subjectID, repository: model.subjectRepository, isAuthenticated: sessionStore.isAuthenticated)
    }
    .sheet(isPresented: $isShowingEditor) {
      if let subject = viewModel.subject {
        NavigationStack {
          CollectionEditorScreen(
            title: subject.nameCN ?? subject.name,
            subjectType: subject.type,
            totalEpisodes: max(viewModel.episodes.count, subject.totalEpisodes ?? subject.eps ?? 0),
            totalVolumes: subject.volumes ?? 0,
            initialPayload: viewModel.editorPayload,
            onSave: { payload in
              Task {
                await viewModel.saveCollection(using: model.subjectRepository, subjectID: subjectID, payload: payload)
              }
            }
          )
        }
      }
    }
  }
}

private struct SubjectHeroCard: View {
  let subject: BangumiSubject
  let collectionTitle: String?
  let watchedEpisodes: Int

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.18),
              Color(uiColor: .secondarySystemGroupedBackground),
              Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top, spacing: 16) {
          Button {
            if let url = subject.images?.best {
              model.presentImage(url)
            }
          } label: {
            CoverImage(url: subject.images?.best)
              .frame(width: 116, height: 154)
              .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
              .overlay(alignment: .bottomTrailing) {
                if subject.nsfw == true {
                  SubjectHeroBadge(title: "NSFW", systemImage: "eye.slash")
                    .padding(10)
                }
              }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("查看封面")

          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
              SubjectCapsuleLabel(title: SubjectType.title(for: subject.type), systemImage: "square.stack")
              if let year = subject.date?.split(separator: "-").first, !year.isEmpty {
                SubjectCapsuleLabel(title: String(year), systemImage: "calendar")
              }
            }

            Text(subject.nameCN ?? subject.name)
              .font(.system(size: 29, weight: .bold, design: .rounded))
              .foregroundStyle(.primary)
              .fixedSize(horizontal: false, vertical: true)

            if let localizedName = subject.nameCN, localizedName != subject.name {
              Text(subject.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
              if let score = subject.rating?.score {
                Text(score, format: .number.precision(.fractionLength(1)))
                  .font(.system(size: 32, weight: .bold, design: .rounded))
                  .foregroundStyle(.primary)
              }

              VStack(alignment: .leading, spacing: 4) {
                if let rank = subject.rating?.rank {
                  Text("Rank #\(rank)")
                    .font(.subheadline.weight(.semibold))
                }
                if let total = subject.rating?.total {
                  Text("\(total) 人评分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }

            if let collectionTitle {
              Label(collectionTitle, systemImage: "books.vertical")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            }
          }
        }

      }
      .padding(20)
    }
  }
}

private struct SubjectActionCard: View {
  let subjectType: Int?
  let isAuthenticated: Bool
  let collectionTitle: String?
  let progressValue: Int
  let totalProgress: Int
  let notificationPermissionState: BangumiNotificationPermissionState
  let notificationSubscription: BangumiSubjectNotificationSubscription?
  let isNotificationUpdating: Bool
  let onEditCollection: () -> Void
  let onToggleNotifications: () -> Void

  @Environment(\.openURL) private var openURL

  private var notificationButtonTitle: String {
    notificationSubscription == nil ? "开启更新提醒" : "关闭更新提醒"
  }

  private var notificationStatusTitle: String {
    if notificationSubscription != nil {
      return notificationPermissionState.canDeliverNotifications ? "新章节会推送到系统通知" : "已订阅，等待系统通知授权"
    }
    return "只在本条目有新章节时提醒"
  }

  private var progressUnitTitle: String {
    if subjectType == SubjectType.book.rawValue {
      return "卷"
    }
    return "集"
  }

  private var progressChipTitle: String {
    if totalProgress > 0 {
      return "\(progressValue) / \(totalProgress) \(progressUnitTitle)"
    }
    return "\(progressValue) \(progressUnitTitle)"
  }

  private var syncChipTitle: String {
    if subjectType == SubjectType.book.rawValue {
      return "卷同步"
    }
    return "逐集同步"
  }

  var body: some View {
    SubjectSectionCard(title: "收藏") {
      VStack(alignment: .leading, spacing: 14) {
        if let collectionTitle {
          HStack {
            Label("当前状态", systemImage: "heart.text.square")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            Spacer()

            Text(collectionTitle)
              .font(.subheadline.weight(.semibold))
          }
        }

        if isAuthenticated {
          Button(action: onEditCollection) {
            HStack {
              Label("编辑收藏", systemImage: "square.and.pencil")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)

          HStack(spacing: 10) {
            SubjectCollectionSummaryChip(
              title: progressChipTitle,
              systemImage: "square.grid.3x2"
            )
            SubjectCollectionSummaryChip(
              title: syncChipTitle,
              systemImage: "sparkles"
            )
          }
        } else {
          Text("登录后可以编辑收藏、同步评分和更新进度。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Divider()

        VStack(alignment: .leading, spacing: 10) {
          Button(action: onToggleNotifications) {
            HStack(spacing: 12) {
              Image(systemName: notificationSubscription == nil ? "bell.badge" : "bell.badge.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(notificationSubscription == nil ? Color.accentColor : Color.orange)
                .frame(width: 28)

              VStack(alignment: .leading, spacing: 4) {
                Text(notificationButtonTitle)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.primary)

                Text(notificationStatusTitle)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer(minLength: 12)

              if isNotificationUpdating {
                ProgressView()
                  .controlSize(.small)
              } else {
                Text(notificationSubscription == nil ? "未开启" : "已开启")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(notificationSubscription == nil ? .secondary : Color.orange)
              }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)

          if notificationPermissionState == .denied || notificationPermissionState == .notDetermined {
            HStack(spacing: 8) {
              Image(systemName: notificationPermissionState.systemImage)
                .foregroundStyle(notificationPermissionState.canDeliverNotifications ? Color.orange : Color.secondary)

              Text(notificationPermissionState.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

              Spacer(minLength: 8)

              if notificationPermissionState == .denied {
                Button("去设置") {
                  guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                  openURL(url)
                }
                .font(.caption.weight(.semibold))
              }
            }
          }
        }
      }
    }
  }
}

private struct SubjectDetailTabBar: View {
  @Binding var selection: SubjectDetailContentTab

  var body: some View {
    Picker("条目内容", selection: $selection) {
      ForEach(SubjectDetailContentTab.allCases) { tab in
        Text(tab.title)
          .tag(tab)
      }
    }
    .pickerStyle(.segmented)
  }
}

private struct SubjectPlainSection<Content: View>: View {
  let title: String
  let actionTitle: String?
  let action: (() -> Void)?
  let content: Content

  init(
    title: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.actionTitle = actionTitle
    self.action = action
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(title)
          .font(BangumiTypography.detailFont(size: 22, weight: .bold))
          .foregroundStyle(.primary)

        Spacer(minLength: 8)

        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .font(BangumiTypography.detailFont(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
      }

      content
    }
  }
}

private struct SubjectSummarySection: View {
  let summary: String
  @Binding var isExpanded: Bool

  private var shouldCollapse: Bool {
    summary.count > 140
  }

  var body: some View {
    SubjectPlainSection(title: "简介") {
      VStack(alignment: .leading, spacing: 12) {
        Text(summary)
          .font(BangumiTypography.detailFont(size: 17))
          .foregroundStyle(.primary)
          .lineSpacing(6)
          .lineLimit(isExpanded ? nil : 5)
          .textSelection(.enabled)

        if shouldCollapse {
          SubjectDisclosureButton(
            title: isExpanded ? "收起简介" : "展开简介",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectPreviewSection: View {
  let items: [BangumiSubjectPreviewItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "预览",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 14) {
          ForEach(items) { item in
            Button {
              if let imageURL = item.imageURL {
                model.presentImage(imageURL)
              } else if let targetURL = item.targetURL {
                model.present(url: targetURL)
              }
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                CoverImage(url: item.imageURL)
                  .frame(width: 262, height: 156)
                  .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(item.title)
                  .font(.headline.weight(.semibold))
                  .foregroundStyle(.primary)
                  .lineLimit(1)

                if let caption = item.caption, !caption.isEmpty {
                  Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              .frame(width: 262, alignment: .leading)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectTagsSection: View {
  let tags: [BangumiTag]
  @Binding var isExpanded: Bool

  private var displayedTags: [BangumiTag] {
    if isExpanded || tags.count <= 12 {
      return tags
    }
    return Array(tags.prefix(12))
  }

  var body: some View {
    SubjectPlainSection(title: "标签") {
      VStack(alignment: .leading, spacing: 12) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(displayedTags, id: \.self) { tag in
            SubjectTagChip(tag: tag)
          }
        }

        if tags.count > 12 {
          SubjectDisclosureButton(
            title: isExpanded ? "收起标签" : "展开全部 \(tags.count) 个标签",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectDetailInfoSection: View {
  let entries: [BangumiSubjectInfoEntry]

  var body: some View {
    SubjectPlainSection(title: "详情") {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          SubjectDetailInfoRow(entry: entry)

          if index < entries.count - 1 {
            Divider()
              .padding(.leading, 104)
          }
        }
      }
    }
  }
}

private struct SubjectDetailLoadingSection: View {
  var body: some View {
    SubjectPlainSection(title: "详情") {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        Text("正在整理详情和职员表…")
          .font(BangumiTypography.detailFont(size: 16))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
    }
  }
}

private struct SubjectDetailInfoRow: View {
  let entry: BangumiSubjectInfoEntry

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Text(entry.label)
        .font(BangumiTypography.detailFont(size: 17, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 90, alignment: .leading)

      BangumiInlineRichText(
        html: entry.htmlValue,
        fallback: entry.textValue
      )
      .font(.body)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct BangumiInlineRichText: View {
  let html: String?
  let fallback: String
  private let baseURL = URL(string: "https://bgm.tv")!

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    Group {
      if let html,
         let attributed = BangumiHTMLParser.attributedString(from: html, baseURL: baseURL),
         !attributed.characters.isEmpty {
        Text(normalizedAttributedString(from: attributed))
          .foregroundStyle(.primary)
          .tint(BangumiTypography.detailLinkColor)
          .lineSpacing(4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      } else {
        Text(fallback)
          .font(BangumiTypography.detailFont(size: 17))
          .foregroundStyle(.primary)
          .lineSpacing(4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      model.present(url: url)
      return .handled
    })
  }

  private func normalizedAttributedString(from attributed: AttributedString) -> AttributedString {
    let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.addAttribute(
      .font,
      value: BangumiTypography.detailUIFont(size: 17),
      range: fullRange
    )
    mutable.addAttribute(
      .foregroundColor,
      value: UIColor.label,
      range: fullRange
    )

    mutable.enumerateAttribute(.link, in: fullRange) { value, range, _ in
      guard value != nil else { return }
      mutable.addAttribute(
        .foregroundColor,
        value: BangumiTypography.detailLinkUIColor,
        range: range
      )
      mutable.addAttribute(
        .underlineStyle,
        value: 0,
        range: range
      )
    }

    if let normalized = try? AttributedString(mutable, including: \.uiKit) {
      return normalized
    }

    return attributed
  }
}

private struct SubjectRatingSection: View {
  let breakdown: BangumiSubjectRatingBreakdown
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  static func fallbackBreakdown(from subject: BangumiSubject) -> BangumiSubjectRatingBreakdown? {
    guard subject.rating?.score != nil || subject.rating?.rank != nil || subject.rating?.total != nil else {
      return nil
    }

    return BangumiSubjectRatingBreakdown(
      average: subject.rating?.score,
      rank: subject.rating?.rank,
      totalVotes: subject.rating?.total,
      buckets: [],
      externalRatings: []
    )
  }

  var body: some View {
    SubjectPlainSection(
      title: "评分",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          if let average = breakdown.average {
            Text(average, format: .number.precision(.fractionLength(1)))
              .font(.system(size: 42, weight: .black, design: .rounded))
              .foregroundStyle(Color.orange)
          }

          if let rank = breakdown.rank {
            Text("\(rank)")
              .font(.headline.weight(.bold))
              .foregroundStyle(.primary)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }

          Spacer(minLength: 8)

          if let totalVotes = breakdown.totalVotes {
            Text("\(totalVotes) votes")
              .font(.headline.weight(.semibold))
              .foregroundStyle(.secondary)
          }
        }

        if !breakdown.buckets.isEmpty {
          SubjectRatingHistogram(buckets: breakdown.buckets)
        }

        if !breakdown.externalRatings.isEmpty {
          HStack(spacing: 10) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
              ForEach(breakdown.externalRatings) { rating in
                HStack(spacing: 6) {
                  Text(rating.source + ":")
                    .foregroundStyle(.secondary)
                  Text(rating.scoreText)
                    .foregroundStyle(.primary)
                  if let votesText = rating.votesText, !votesText.isEmpty {
                    Text("(\(votesText))")
                      .foregroundStyle(.secondary)
                  }
                }
                .font(.footnote.weight(.medium))
              }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectRatingHistogram: View {
  let buckets: [BangumiSubjectRatingBucket]

  private var maxCount: Int {
    buckets.map(\.count).max() ?? 1
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 14) {
      ForEach(buckets) { bucket in
        VStack(spacing: 8) {
          Text("\(bucket.count)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)

          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(0.7))
            .frame(width: 14, height: max(8, CGFloat(bucket.count) / CGFloat(maxCount) * 128))

          Text("\(bucket.score)")
            .font(.headline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 4)
  }
}

private struct SubjectCollectionStatsSection: View {
  let stats: BangumiSubjectCollectionStats

  var body: some View {
    let items = [
      ("在看", stats.doing ?? 0),
      ("看过", stats.collect ?? 0),
      ("想看", stats.wish ?? 0),
      ("搁置", stats.onHold ?? 0),
      ("抛弃", stats.dropped ?? 0)
    ]
    .filter { $0.1 > 0 }

    if !items.isEmpty {
      SubjectPlainSection(title: "收藏概览") {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 88), spacing: 10)],
          spacing: 10
        ) {
          ForEach(items, id: \.0) { item in
            VStack(alignment: .leading, spacing: 6) {
              Text(item.0)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("\(item.1)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectCastSection: View {
  let items: [BangumiSubjectCastItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "角色",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Button {
              if let detailURL = item.detailURL {
                model.present(url: detailURL)
              }
            } label: {
              SubjectPersonRailCard(
                imageURL: item.imageURL,
                title: item.name,
                subtitle: item.subtitle,
                role: item.actorName ?? item.role,
                accentText: item.accentText
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectStaffSection: View {
  let items: [BangumiSubjectStaffItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "制作人员",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Button {
              if let detailURL = item.detailURL {
                model.present(url: detailURL)
              }
            } label: {
              SubjectPersonRailCard(
                imageURL: item.imageURL,
                title: item.name,
                subtitle: item.subtitle,
                role: item.roles,
                accentText: item.accentText
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectRelationSection: View {
  let items: [BangumiSubjectRelationItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "关联",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Group {
              if let subjectID = item.subjectID {
                NavigationLink {
                  SubjectDetailScreen(subjectID: subjectID)
                } label: {
                  SubjectRelationRailCard(item: item)
                }
                .buttonStyle(.plain)
              } else {
                Button {
                  if let detailURL = item.detailURL {
                    model.present(url: detailURL)
                  }
                } label: {
                  SubjectRelationRailCard(item: item)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
      }
    }
  }
}

private struct SubjectPersonRailCard: View {
  let imageURL: URL?
  let title: String
  let subtitle: String?
  let role: String?
  let accentText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      CoverImage(url: imageURL)
        .frame(width: 104, height: 134)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let role, !role.isEmpty {
        Text(role)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      if let accentText, !accentText.isEmpty {
        Text(accentText)
          .font(.headline.weight(.bold))
          .foregroundStyle(.pink)
      }
    }
    .frame(width: 104, alignment: .topLeading)
  }
}

private struct SubjectRelationRailCard: View {
  let item: BangumiSubjectRelationItem

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      CoverImage(url: item.imageURL)
        .frame(width: 118, height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(item.title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      if let subtitle = item.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let relationLabel = item.relationLabel, !relationLabel.isEmpty {
        Text(relationLabel)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.pink)
          .lineLimit(1)
      }
    }
    .frame(width: 118, alignment: .topLeading)
  }
}

private struct SubjectTagsCard: View {
  let tags: [BangumiTag]
  @Binding var isExpanded: Bool

  private var displayedTags: [BangumiTag] {
    if isExpanded || tags.count <= 8 {
      return tags
    }
    return Array(tags.prefix(8))
  }

  var body: some View {
    SubjectSectionCard(title: "标签") {
      VStack(alignment: .leading, spacing: 12) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(displayedTags, id: \.self) { tag in
            SubjectTagChip(tag: tag)
          }
        }

        if tags.count > 8 {
          SubjectDisclosureButton(
            title: isExpanded ? "收起标签" : "展开全部 \(tags.count) 个标签",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectSummaryCard: View {
  let summary: String
  @Binding var isExpanded: Bool

  private var shouldCollapse: Bool {
    summary.count > 140
  }

  var body: some View {
    SubjectSectionCard(title: "简介") {
      VStack(alignment: .leading, spacing: 12) {
        Text(summary)
          .font(.body)
          .foregroundStyle(.primary)
          .lineSpacing(5)
          .lineLimit(isExpanded ? nil : 4)
          .textSelection(.enabled)

        if shouldCollapse {
          SubjectDisclosureButton(
            title: isExpanded ? "收起简介" : "展开简介",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectInfoGridCard: View {
  let subject: BangumiSubject

  var body: some View {
    let items = metadataItems

    if !items.isEmpty {
      SubjectSectionCard(title: "信息") {
        VStack(spacing: 10) {
          ForEach(items, id: \.title) { item in
            SubjectInfoTile(title: item.title, value: item.value, systemImage: item.systemImage)
          }
        }
      }
    }
  }

  private var metadataItems: [(title: String, value: String, systemImage: String)] {
    var items: [(String, String, String)] = []

    if let date = subject.date, !date.isEmpty {
      items.append((dateTitle, date, "calendar"))
    }
    if let totalEpisodes = subject.totalEpisodes ?? subject.eps, totalEpisodes > 0 {
      items.append(("章节数量", "\(totalEpisodes)", "play.square.stack"))
    }
    if let volumes = subject.volumes, volumes > 0 {
      items.append(("卷数", "\(volumes)", "books.vertical"))
    }
    if let platform = subject.platform, !platform.isEmpty {
      items.append(("平台", platform, "shippingbox"))
    }
    if subject.locked == true {
      items.append(("状态", "锁定", "lock"))
    }
    return items
  }

  private var dateTitle: String {
    guard let type = SubjectType(rawValue: subject.type ?? 0) else {
      return "日期"
    }

    switch type {
    case .anime:
      if let platform = subject.platform?.lowercased() {
        if platform.contains("剧场") || platform.contains("movie") || platform.contains("film") || platform.contains("电影") {
          return "上映日期"
        }
      }
      return "放送日期"
    case .book:
      return "出版日期"
    case .music:
      return "发售日期"
    case .game:
      return "发售日期"
    case .real:
      if let platform = subject.platform?.lowercased() {
        if platform.contains("电影") || platform.contains("movie") || platform.contains("film") {
          return "上映日期"
        }
      }
      return "首播日期"
    }
  }
}

private struct SubjectDisclosureButton: View {
  let title: String
  let isExpanded: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title)
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.caption.weight(.bold))
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
  }
}

private struct SubjectCollectionStatsCard: View {
  let stats: BangumiSubjectCollectionStats

  var body: some View {
    let items = [
      ("在看", stats.doing ?? 0),
      ("看过", stats.collect ?? 0),
      ("想看", stats.wish ?? 0),
      ("搁置", stats.onHold ?? 0),
      ("抛弃", stats.dropped ?? 0)
    ]
    .filter { $0.1 > 0 }

    if !items.isEmpty {
      SubjectSectionCard(title: "收藏概览") {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 88), spacing: 10)],
          spacing: 10
        ) {
          ForEach(items, id: \.0) { item in
            VStack(alignment: .leading, spacing: 6) {
              Text(item.0)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("\(item.1)")
                .font(.title3.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectEpisodeProgressSection: View {
  let episodes: [BangumiEpisode]
  let statuses: [Int: BangumiEpisodeCollectionType]
  let watchedEpisodes: Int
  let isAuthenticated: Bool
  let updatingEpisodeID: Int?
  let onSelectStatus: (BangumiEpisode, BangumiEpisodeCollectionType) -> Void

  private let columns = [
    GridItem(.adaptive(minimum: 48, maximum: 58), spacing: 12, alignment: .top)
  ]

  var body: some View {
    SubjectSectionCard(title: "进度") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 5) {
            Text(isAuthenticated ? "已同步 \(watchedEpisodes) 集" : "游客模式下可浏览章节信息")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          SubjectProgressCountBadge(
            watchedEpisodes: watchedEpisodes,
            totalEpisodes: episodes.count
          )
        }

        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
          ForEach(episodes) { episode in
            SubjectEpisodeProgressTile(
              episode: episode,
              status: statuses[episode.id] ?? .none,
              isAuthenticated: isAuthenticated,
              isUpdating: updatingEpisodeID == episode.id,
              onSelectStatus: onSelectStatus
            )
          }
        }
      }
    }
  }
}

private struct SubjectEpisodeProgressTile: View {
  let episode: BangumiEpisode
  let status: BangumiEpisodeCollectionType
  let isAuthenticated: Bool
  let isUpdating: Bool
  let onSelectStatus: (BangumiEpisode, BangumiEpisodeCollectionType) -> Void

  var body: some View {
    Menu {
      SubjectEpisodeActionMenuContent(
        episode: episode,
        currentStatus: status,
        isAuthenticated: isAuthenticated,
        isUpdating: isUpdating,
        onSelectStatus: { nextStatus in
          onSelectStatus(episode, nextStatus)
        }
      )
    } label: {
      VStack(spacing: 0) {
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tileFill)
          Text(tileLabel)
            .font(.system(size: tileLabel.count > 3 ? 16 : 20, weight: .bold, design: .rounded))
            .foregroundStyle(tileForeground)
            .minimumScaleFactor(0.72)
          if isUpdating {
            ProgressView()
              .tint(tileForeground)
          }
        }
        .frame(height: 52)

        RoundedRectangle(cornerRadius: 999, style: .continuous)
          .fill(indicatorFill)
          .frame(height: 5)
          .padding(.horizontal, 4)
          .padding(.top, 6)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isUpdating)
    .accessibilityLabel("\(episode.nameCN ?? episode.name ?? "未知章节")，\(status.title)")
    .accessibilityHint("展开章节操作")
  }

  private var tileLabel: String {
    guard let sort = episode.sort else { return "?" }
    if sort.rounded(.towardZero) == sort {
      return "\(Int(sort))"
    }
    return sort.formatted(.number.precision(.fractionLength(1)))
  }

  private var tileFill: Color {
    switch status {
    case .watched:
      return Color.accentColor
    case .wish:
      return Color.accentColor.opacity(0.18)
    case .dropped:
      return Color(uiColor: .systemGray5)
    case .none:
      return Color(uiColor: .secondarySystemGroupedBackground)
    }
  }

  private var tileForeground: Color {
    switch status {
    case .watched:
      return .white
    case .wish:
      return .accentColor
    case .dropped:
      return Color(uiColor: .secondaryLabel)
    case .none:
      return .primary
    }
  }

  private var indicatorFill: Color {
    switch status {
    case .watched:
      return Color.orange.opacity(0.72)
    case .wish:
      return Color.accentColor.opacity(0.55)
    case .dropped:
      return Color(uiColor: .systemGray3)
    case .none:
      return Color(uiColor: .systemGray5)
    }
  }
}

private struct SubjectEpisodeActionMenuContent: View {
  let episode: BangumiEpisode
  let currentStatus: BangumiEpisodeCollectionType
  let isAuthenticated: Bool
  let isUpdating: Bool
  let onSelectStatus: (BangumiEpisodeCollectionType) -> Void

  var body: some View {
    Group {
      Button(episodeDisplayLabel) {}
        .disabled(true)

      if let localizedName = episode.nameCN ?? episode.name, !localizedName.isEmpty {
        Button(localizedName) {}
          .disabled(true)
      }

      if let originalName = episode.name,
         let localizedName = episode.nameCN,
         originalName != localizedName {
        Button(originalName) {}
          .disabled(true)
      }

      if let airdate = episode.airdate, !airdate.isEmpty {
        Button(airdate) {}
          .disabled(true)
      }

      Divider()

      if isAuthenticated {
        ForEach([
          BangumiEpisodeCollectionType.watched,
          .wish,
          .dropped,
          .none
        ], id: \.self) { status in
          Button {
            onSelectStatus(status)
          } label: {
            if currentStatus == status {
              Label(status == .none ? "撤销" : status.title, systemImage: "checkmark")
            } else {
              Text(status == .none ? "撤销" : status.title)
            }
          }
          .disabled(isUpdating)
        }
      } else {
        Button("登录后可同步这一集的状态。") {}
          .disabled(true)
      }
    }
  }

  private var episodeDisplayLabel: String {
    guard let sort = episode.sort else { return "EP ?" }
    if sort.rounded(.towardZero) == sort {
      return "EP \(Int(sort))"
    }
    return "EP \(sort.formatted(.number.precision(.fractionLength(1))))"
  }
}

private struct SubjectCommentsSection: View {
  let comments: [BangumiSubjectComment]
  let isLoading: Bool
  let errorMessage: String?
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "吐槽",
      actionTitle: moreURL == nil ? nil : "更多吐槽",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      VStack(alignment: .leading, spacing: 0) {
        if isLoading && comments.isEmpty {
          ProgressView("正在读取吐槽...")
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if comments.isEmpty {
          Text(errorMessage ?? "暂时没有读取到公开吐槽。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(comments) { comment in
            SubjectCommentRow(comment: comment)
            if comment.id != (comments.last?.id ?? "") {
              Divider()
                .padding(.leading, 64)
                .padding(.vertical, 18)
            }
          }
        }

        if let errorMessage, !errorMessage.isEmpty, !comments.isEmpty {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
        }
      }
    }
  }
}

private struct SubjectCommentRow: View {
  let comment: BangumiSubjectComment

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CoverImage(url: comment.avatarURL)
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          UserNameButton(
            title: comment.userName,
            userID: comment.userID,
            font: .system(size: 19, weight: .bold)
          )
          .lineLimit(1)

          Spacer(minLength: 0)
        }

        if !metaLine.isEmpty {
          Text(metaLine)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(comment.message)
          .font(.system(size: 16, weight: .regular))
          .foregroundStyle(.primary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 1)
    }
  }

  private var metaLine: String {
    var parts: [String] = []

    if let userSign = comment.userSign?.trimmingCharacters(in: .whitespacesAndNewlines),
       !userSign.isEmpty {
      parts.append(userSign)
    }

    let time = localizedTime(comment.time)
    if !time.isEmpty {
      parts.append(time)
    }

    return parts.joined(separator: " · ")
  }

  private func localizedTime(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.localizedCaseInsensitiveContains("ago") else { return trimmed }

    var localized = trimmed
      .replacingOccurrences(of: " ago", with: "前")
      .replacingOccurrences(of: "h ", with: "小时")
      .replacingOccurrences(of: "m ", with: "分钟")
      .replacingOccurrences(of: "d ", with: "天")
      .replacingOccurrences(of: "h", with: "小时")
      .replacingOccurrences(of: "m", with: "分钟")
      .replacingOccurrences(of: "d", with: "天")
      .replacingOccurrences(of: "Just now", with: "刚刚")

    localized = localized
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return localized
  }
}

private struct SubjectSectionCard<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.title3.weight(.bold))
        .foregroundStyle(.primary)

      content
    }
    .bangumiCardStyle()
  }
}

private struct SubjectInlineMessageCard: View {
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(.orange)
      Text(message)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct SubjectCollectionSummaryChip: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
  }
}

private struct SubjectProgressCountBadge: View {
  let watchedEpisodes: Int
  let totalEpisodes: Int

  var body: some View {
    VStack(alignment: .trailing, spacing: 3) {
      Text(totalEpisodes > 0 ? "\(watchedEpisodes) / \(totalEpisodes)" : "\(watchedEpisodes)")
        .font(.system(size: 21, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      Text("已标记")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct SubjectCapsuleLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.white.opacity(0.68), in: Capsule())
  }
}

private struct SubjectHeroBadge: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.black.opacity(0.55), in: Capsule())
  }
}

private struct SubjectMetricTile: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.footnote.weight(.semibold))
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct SubjectInfoTile: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage)
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      Spacer(minLength: 16)

      Text(value)
        .font(.system(.body, design: .default, weight: .semibold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: 320, minHeight: 46, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct SubjectTagChip: View {
  let tag: BangumiTag

  var body: some View {
    HStack(spacing: 6) {
      Text(tag.name)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.84)
        .layoutPriority(1)
      if let count = tag.count {
        Text("\(count)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private final class SubjectDetailViewModel: ObservableObject {
  @Published var subject: BangumiSubject?
  @Published var presentation: BangumiSubjectPresentation = .empty
  @Published var episodes: [BangumiEpisode] = []
  @Published var collection: BangumiSubjectCollectionRecord?
  @Published var episodeStatuses: [Int: BangumiEpisodeCollectionType] = [:]
  @Published var comments: [BangumiSubjectComment] = []
  @Published var watchedEpisodes = 0
  @Published var isLoading = false
  @Published var isLoadingComments = false
  @Published var isLoadingPresentation = false
  @Published var updatingEpisodeID: Int?
  @Published var errorMessage: String?
  @Published var commentsErrorMessage: String?

  var navigationTitle: String {
    if let subject {
      return subject.nameCN ?? subject.name
    }
    return "条目详情"
  }

  var editorPayload: CollectionUpdatePayload {
    CollectionUpdatePayload(
      status: statusFromCollection(collection),
      rating: collection?.rate ?? 0,
      tags: collection?.tags?.joined(separator: " ") ?? "",
      comment: collection?.comment ?? "",
      isPrivate: false,
      watchedEpisodes: collection?.epStatus ?? 0,
      watchedVolumes: collection?.volStatus ?? 0
    )
  }

  @MainActor
  func load(subjectID: Int, repository: SubjectRepository, isAuthenticated: Bool) async {
    isLoading = true
    isLoadingComments = true
    isLoadingPresentation = true
    errorMessage = nil
    commentsErrorMessage = nil
    presentation = .empty
    defer { isLoading = false }

    do {
      async let subjectTask = repository.fetchSubject(id: subjectID)
      async let episodesResult: Result<[BangumiEpisode], Error> = loadResult {
        try await repository.fetchEpisodes(subjectID: subjectID)
      }
      async let commentsResult: Result<[BangumiSubjectComment], Error> = loadResult {
        try await repository.fetchSubjectComments(subjectID: subjectID)
      }
      async let presentationResult: Result<BangumiSubjectPresentation, Error> = loadResult {
        try await repository.fetchSubjectPresentation(subjectID: subjectID)
      }
      async let collectionResult: Result<BangumiSubjectCollectionRecord?, Error> = loadOptionalResult {
        guard isAuthenticated else { return nil }
        return try await repository.fetchCollection(subjectID: subjectID)
      }
      async let episodeCollectionsResult: Result<[BangumiEpisodeCollection], Error> = loadResult {
        guard isAuthenticated else { return [BangumiEpisodeCollection]() }
        return try await repository.fetchEpisodeCollections(subjectID: subjectID)
      }

      let loadedSubject = try await subjectTask
      subject = loadedSubject

      let resolvedEpisodesResult = await episodesResult
      let resolvedEpisodes: [BangumiEpisode]
      switch resolvedEpisodesResult {
      case let .success(loadedEpisodes):
        resolvedEpisodes = loadedEpisodes
        episodes = loadedEpisodes
      case let .failure(error):
        resolvedEpisodes = []
        episodes = []
        errorMessage = "章节信息加载不完整：\(error.localizedDescription)"
      }

      let resolvedCommentsResult = await commentsResult
      switch resolvedCommentsResult {
      case let .success(loadedComments):
        comments = loadedComments
        commentsErrorMessage = nil
      case let .failure(error):
        comments = []
        commentsErrorMessage = "吐槽加载失败：\(error.localizedDescription)"
      }
      isLoadingComments = false

      switch await presentationResult {
      case let .success(loadedPresentation):
        presentation = loadedPresentation
      case .failure:
        presentation = .empty
      }
      isLoadingPresentation = false

      let resolvedCollectionResult = await collectionResult
      let resolvedCollection: BangumiSubjectCollectionRecord?
      switch resolvedCollectionResult {
      case let .success(loadedCollection):
        resolvedCollection = loadedCollection
      case .failure:
        resolvedCollection = nil
      }
      collection = resolvedCollection

      let resolvedEpisodeCollections: [BangumiEpisodeCollection]
      switch await episodeCollectionsResult {
      case let .success(collections):
        resolvedEpisodeCollections = collections
      case .failure:
        resolvedEpisodeCollections = []
        if loadedSubject.type == SubjectType.anime.rawValue && errorMessage == nil {
          errorMessage = "逐集进度暂时无法同步，已先显示基础信息。"
        }
      }

      episodeStatuses = mergedEpisodeStatuses(
        episodes: resolvedEpisodes,
        explicitCollections: resolvedEpisodeCollections,
        fallbackWatchedEpisodes: resolvedCollection?.epStatus ?? 0
      )
      watchedEpisodes = resolvedCollection?.epStatus ?? countedWatchedEpisodes(from: episodeStatuses)
      if !episodeStatuses.isEmpty {
        watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
      }

      let shouldHintEpisodeFallback =
        loadedSubject.type == SubjectType.anime.rawValue &&
        max(loadedSubject.eps ?? 0, loadedSubject.totalEpisodes ?? 0) > 0 &&
        resolvedEpisodes.isEmpty

      if shouldHintEpisodeFallback {
        errorMessage = "章节列表暂时不可用，条目基础信息已加载。"
      }
    } catch {
      errorMessage = error.localizedDescription
      presentation = .empty
      isLoadingComments = false
      isLoadingPresentation = false
    }
  }

  @MainActor
  func saveCollection(using repository: SubjectRepository, subjectID: Int, payload: CollectionUpdatePayload) async {
    do {
      try await repository.updateCollection(subjectID: subjectID, payload: payload)
      if payload.watchedEpisodes != nil || payload.watchedVolumes != nil {
        try await repository.updateWatchedProgress(
          subjectID: subjectID,
          watchedEpisodes: payload.watchedEpisodes,
          watchedVolumes: payload.watchedVolumes
        )
      }
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      errorMessage = nil
    } catch {
      errorMessage = "收藏保存失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  func saveProgress(using repository: SubjectRepository, subjectID: Int) async {
    do {
      try await repository.updateWatchedProgress(subjectID: subjectID, watchedEpisodes: watchedEpisodes)
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      errorMessage = nil
    } catch {
      errorMessage = "进度更新失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  func markEpisodeWatched(using repository: SubjectRepository, episodeID: Int) async {
    do {
      try await repository.markEpisodeWatched(episodeID: episodeID)
      episodeStatuses[episodeID] = .watched
      watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
      errorMessage = nil
    } catch {
      errorMessage = "章节状态更新失败：\(error.localizedDescription)"
    }
  }

  func status(for episode: BangumiEpisode) -> BangumiEpisodeCollectionType {
    episodeStatuses[episode.id] ?? .none
  }

  @MainActor
  func updateEpisodeStatus(
    using repository: SubjectRepository,
    subjectID: Int,
    episode: BangumiEpisode,
    status: BangumiEpisodeCollectionType,
    isAuthenticated: Bool
  ) async -> Bool {
    guard isAuthenticated else {
      errorMessage = "登录后才可以同步逐集进度。"
      return false
    }

    let previousStatus = episodeStatuses[episode.id] ?? .none
    updatingEpisodeID = episode.id
    applyEpisodeStatus(status, for: episode.id)
    errorMessage = nil

    do {
      try await repository.updateEpisodeCollection(episodeID: episode.id, type: status)
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      updatingEpisodeID = nil
      return true
    } catch {
      applyEpisodeStatus(previousStatus, for: episode.id)
      errorMessage = "章节状态更新失败：\(error.localizedDescription)"
      updatingEpisodeID = nil
      return false
    }
  }

  func collectionTitle(from collection: BangumiSubjectCollectionRecord) -> String {
    guard let type = collection.type else { return "未收藏" }
    return Self.statusTitle(for: type)
  }

  private func statusFromCollection(_ collection: BangumiSubjectCollectionRecord?) -> CollectionStatus {
    guard let type = collection?.type else { return CollectionStatus.doing }
    switch type {
    case "1", "wish": return CollectionStatus.wish
    case "2", "collect": return CollectionStatus.collect
    case "4", "on_hold": return CollectionStatus.onHold
    case "5", "dropped": return CollectionStatus.dropped
    default: return CollectionStatus.doing
    }
  }

  private static func statusTitle(for raw: String) -> String {
    switch raw {
    case "1", "wish": "想看"
    case "2", "collect": "看过"
    case "4", "on_hold": "搁置"
    case "5", "dropped": "抛弃"
    default: "在看"
    }
  }

  private func applyEpisodeStatus(_ status: BangumiEpisodeCollectionType, for episodeID: Int) {
    if status == .none {
      episodeStatuses.removeValue(forKey: episodeID)
    } else {
      episodeStatuses[episodeID] = status
    }
    watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
  }

  private func mergedEpisodeStatuses(
    episodes: [BangumiEpisode],
    explicitCollections: [BangumiEpisodeCollection],
    fallbackWatchedEpisodes: Int
  ) -> [Int: BangumiEpisodeCollectionType] {
    var merged = explicitCollections.reduce(into: [Int: BangumiEpisodeCollectionType]()) { partialResult, item in
      if item.type != .none {
        partialResult[item.episodeID] = item.type
      }
    }

    guard fallbackWatchedEpisodes > 0 else { return merged }

    for episode in episodes {
      guard merged[episode.id] == nil else { continue }
      if let sort = episode.sort, sort > 0, sort <= Double(fallbackWatchedEpisodes) {
        merged[episode.id] = .watched
      }
    }

    return merged
  }

  private func countedWatchedEpisodes(from statuses: [Int: BangumiEpisodeCollectionType]) -> Int {
    statuses.values.filter { $0 == .watched }.count
  }

  private func loadResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
    do {
      return .success(try await operation())
    } catch {
      return .failure(error)
    }
  }

  private func loadOptionalResult<T>(_ operation: @escaping () async throws -> T?) async -> Result<T?, Error> {
    do {
      return .success(try await operation())
    } catch {
      return .failure(error)
    }
  }
}

private struct CollectionEditorScreen: View {
  let title: String
  let subjectType: Int?
  let totalEpisodes: Int
  let totalVolumes: Int
  let initialPayload: CollectionUpdatePayload
  let onSave: (CollectionUpdatePayload) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var status: CollectionStatus
  @State private var rating: Int
  @State private var tags: String
  @State private var comment: String
  @State private var isPrivate: Bool
  @State private var watchedEpisodes: Int
  @State private var watchedVolumes: Int

  private var isBook: Bool {
    subjectType == SubjectType.book.rawValue
  }

  init(
    title: String,
    subjectType: Int?,
    totalEpisodes: Int,
    totalVolumes: Int,
    initialPayload: CollectionUpdatePayload,
    onSave: @escaping (CollectionUpdatePayload) -> Void
  ) {
    self.title = title
    self.subjectType = subjectType
    self.totalEpisodes = totalEpisodes
    self.totalVolumes = totalVolumes
    self.initialPayload = initialPayload
    self.onSave = onSave
    _status = State(initialValue: initialPayload.status)
    _rating = State(initialValue: initialPayload.rating)
    _tags = State(initialValue: initialPayload.tags)
    _comment = State(initialValue: initialPayload.comment)
    _isPrivate = State(initialValue: initialPayload.isPrivate)
    _watchedEpisodes = State(initialValue: initialPayload.watchedEpisodes ?? 0)
    _watchedVolumes = State(initialValue: initialPayload.watchedVolumes ?? 0)
  }

  var body: some View {
    Form {
      Section(title) {
        Picker("收藏状态", selection: $status) {
          ForEach(CollectionStatus.allCases) { status in
            Text(status.title).tag(status)
          }
        }

        Stepper("评分 \(rating)", value: $rating, in: 0 ... 10)

        if isBook, totalVolumes > 0 {
          Stepper(
            "已读卷数 \(watchedVolumes)/\(totalVolumes)",
            value: $watchedVolumes,
            in: 0 ... totalVolumes
          )
        } else if totalEpisodes > 0 {
          Stepper(
            "已看进度 \(watchedEpisodes)/\(totalEpisodes)",
            value: $watchedEpisodes,
            in: 0 ... totalEpisodes
          )
        }

        TextField("标签（空格分隔）", text: $tags)
        TextField("短评", text: $comment, axis: .vertical)
        Toggle("私密收藏", isOn: $isPrivate)
      }
    }
    .navigationTitle("编辑收藏")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("关闭") {
          dismiss()
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button("保存") {
          onSave(
            CollectionUpdatePayload(
              status: status,
              rating: rating,
              tags: tags,
              comment: comment,
              isPrivate: isPrivate,
              watchedEpisodes: isBook ? nil : watchedEpisodes,
              watchedVolumes: isBook ? watchedVolumes : nil
            )
          )
          dismiss()
        }
      }
    }
  }
}

private struct RakuenScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = RakuenViewModel()

  var body: some View {
    ScreenScaffold(
      title: "Rakuen",
      subtitle: "V1 先接入原生列表，主题详情暂保留 Web 回退。",
      navigationBarStyle: .discoveryNative
    ) {
      Group {
        if viewModel.isLoading && viewModel.items.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
          UnavailableStateView(
            title: "Rakuen 加载失败",
            systemImage: "bubble.left.and.bubble.right",
            message: error
          )
        } else {
          List {
            Section {
              Picker("类型", selection: $viewModel.filter) {
                ForEach(RakuenFilter.allCases) { filter in
                  Text(filter.title).tag(filter)
                }
              }
              .pickerStyle(.segmented)
            }

            ForEach(viewModel.items) { item in
              NavigationLink {
                RakuenTopicScreen(topicURL: item.topicURL, fallbackTitle: item.title)
              } label: {
                RakuenRow(item: item)
              }
            }
          }
          .refreshable {
            await viewModel.refresh(using: model.rakuenRepository)
          }
          .bangumiRootScrollableLayout()
        }
      }
      .task {
        await viewModel.bootstrap(using: model.rakuenRepository)
      }
      .onChange(of: viewModel.filter) { _ in
        Task {
          await viewModel.refresh(using: model.rakuenRepository)
        }
      }
    }
  }
}

private final class RakuenViewModel: ObservableObject {
  @Published var items: [BangumiRakuenItem] = []
  @Published var filter: RakuenFilter = .all
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var hasBootstrapped = false

  @MainActor
  func bootstrap(using repository: RakuenRepository) async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    await refresh(using: repository)
  }

  @MainActor
  func refresh(using repository: RakuenRepository) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      items = try await repository.fetch(filter: filter)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct RakuenRow: View {
  let item: BangumiRakuenItem

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: item.avatarURL)
        .frame(width: 42, height: 42)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        Text(item.title)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(2)

        HStack(spacing: 8) {
          Text(item.userName)
          if let groupName = item.groupName, !groupName.isEmpty {
            Text(groupName)
          }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)

        HStack(spacing: BangumiDesign.sectionSpacing) {
          if !item.time.isEmpty {
            Label(item.time, systemImage: "clock")
          }
          if let replyCount = item.replyCount {
            Label(replyCount, systemImage: "text.bubble")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct RakuenTopicScreen: View {
  let topicURL: URL?
  let fallbackTitle: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = RakuenTopicViewModel()

  var body: some View {
    Group {
      if let topicURL {
        content(for: topicURL)
      } else {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "bubble.left.and.bubble.right",
          message: "暂时没有可用的帖子地址。"
        )
      }
    }
    .task(id: topicURL?.absoluteString) {
      guard let topicURL else { return }
      await viewModel.load(using: model.rakuenRepository, url: topicURL)
    }
    .navigationTitle(viewModel.detail?.topic.title ?? fallbackTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let topicURL {
        ToolbarItem(placement: .topBarTrailing) {
          Link(destination: topicURL) {
            Label("在 Safari 中打开", systemImage: "safari")
              .labelStyle(.iconOnly)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func content(for topicURL: URL) -> some View {
    if viewModel.isLoading && viewModel.detail == nil {
      ProgressView("加载中...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = viewModel.errorMessage, viewModel.detail == nil {
      UnavailableStateView(
        title: fallbackTitle,
        systemImage: "exclamationmark.triangle",
        message: error
      )
    } else if let detail = viewModel.detail, viewModel.hasRenderableContent {
      List {
        Section("主楼") {
          RakuenPostCard(
            avatarURL: detail.topic.avatarURL,
            userName: detail.topic.userName,
            userID: detail.topic.userID,
            userSign: detail.topic.userSign,
            floor: detail.topic.floor,
            time: detail.topic.time,
            message: detail.topic.message,
            htmlMessage: detail.topic.htmlMessage
          )

          if let groupName = detail.topic.groupName, !groupName.isEmpty {
            LabeledContent("版块", value: groupName)
          }
        }

        if detail.comments.isEmpty {
          Section("回复") {
            Text("当前没有解析到回复，稍后可以点右上角 Safari 回退到网页。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        } else {
          Section("回复 \(detail.comments.count)") {
            ForEach(detail.comments) { comment in
              RakuenPostCard(
                avatarURL: comment.avatarURL,
                userName: comment.userName,
                userID: comment.userID,
                userSign: comment.userSign,
                floor: comment.floor,
                time: comment.time,
                message: comment.message,
                htmlMessage: comment.htmlMessage,
                subReplies: comment.subReplies
              )
            }
          }
        }
      }
      .refreshable {
        await viewModel.refresh(using: model.rakuenRepository, url: topicURL)
      }
    } else {
      UnavailableStateView(
        title: fallbackTitle,
        systemImage: "bubble.left.and.bubble.right",
        message: "暂时没有解析到帖子内容，可以先用右上角 Safari 查看原文。"
      )
    }
  }
}

private final class RakuenTopicViewModel: ObservableObject {
  @Published var detail: BangumiRakuenTopicDetail?
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var hasAttemptedLoad = false

  private var loadedURL: URL?

  var hasRenderableContent: Bool {
    guard let detail else { return false }
    let topicMessage = detail.topic.message.trimmingCharacters(in: .whitespacesAndNewlines)
    let topicHTML = detail.topic.htmlMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !topicMessage.isEmpty || !topicHTML.isEmpty || !detail.comments.isEmpty
  }

  @MainActor
  func load(using repository: RakuenRepository, url: URL) async {
    if loadedURL == url, detail != nil { return }
    await refresh(using: repository, url: url)
  }

  @MainActor
  func refresh(using repository: RakuenRepository, url: URL) async {
    isLoading = true
    hasAttemptedLoad = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      detail = try await repository.fetchTopic(url: url)
      loadedURL = url
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct RakuenPostCard: View {
  let avatarURL: URL?
  let userName: String
  var userID: String? = nil
  let userSign: String?
  let floor: String?
  let time: String
  let message: String
  var htmlMessage: String? = nil
  var subReplies: [BangumiRakuenSubReply] = []

  var body: some View {
    VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
      HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
        CoverImage(url: avatarURL)
          .frame(width: 40, height: 40)
          .clipShape(Circle())
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          HStack(alignment: .firstTextBaseline, spacing: BangumiDesign.sectionSpacing) {
            UserNameButton(title: userName, userID: userID)

            if let floor, !floor.isEmpty {
              Text(floor)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if let userSign, !userSign.isEmpty {
            Text(userSign)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let htmlMessage, !htmlMessage.isEmpty {
            BangumiRichText(html: htmlMessage)
              .textSelection(.enabled)
          } else if !message.isEmpty {
            Text(message)
              .font(.body)
              .textSelection(.enabled)
          }

          if !time.isEmpty {
            Label(time, systemImage: "clock")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !subReplies.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(subReplies) { reply in
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline, spacing: BangumiDesign.sectionSpacing) {
                UserNameButton(title: reply.userName, userID: reply.userID, font: .subheadline)
                  .bold()

                if let floor = reply.floor, !floor.isEmpty {
                  Text(floor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              if let userSign = reply.userSign, !userSign.isEmpty {
                Text(userSign)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              if let htmlMessage = reply.htmlMessage, !htmlMessage.isEmpty {
                BangumiRichText(html: htmlMessage)
                  .font(.subheadline)
                  .textSelection(.enabled)
              } else {
                Text(reply.message)
                  .font(.subheadline)
                  .textSelection(.enabled)
              }

              if !reply.time.isEmpty {
                Label(reply.time, systemImage: "clock")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(BangumiDesign.cardPadding)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(.leading, 52)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct NotificationManagementScreen: View {
  var showsDismissButton = false

  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: notificationStore.permissionState.systemImage)
              .font(.title2.weight(.semibold))
              .foregroundStyle(notificationStore.permissionState.canDeliverNotifications ? Color.orange : Color.secondary)
              .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
              Text(notificationStore.permissionState.title)
                .font(.headline)

              Text(notificationStore.permissionState.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
          }

          HStack(spacing: 12) {
            Button {
              Task {
                await notificationStore.performManualCheck()
              }
            } label: {
              HStack {
                if notificationStore.isCheckingUpdates {
                  ProgressView()
                    .controlSize(.small)
                } else {
                  Image(systemName: "arrow.clockwise")
                }
                Text(notificationStore.isCheckingUpdates ? "检查中..." : "立即检查更新")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(notificationStore.isCheckingUpdates)

            if notificationStore.permissionState == .denied {
              Button("去设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
              }
              .buttonStyle(.bordered)
            }
          }

          if let lastCheckedAt = notificationStore.lastCheckedAt {
            Text("最近检查：\(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let statusMessage = notificationStore.statusMessage, !statusMessage.isEmpty {
            Text(statusMessage)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .bangumiCardStyle()
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section("已订阅条目") {
        if notificationStore.subscriptions.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("还没有开启任何条目提醒。")
              .font(.headline)
            Text("去任意条目详情页开启“更新提醒”后，这里会集中管理全部订阅。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
        } else {
          ForEach(notificationStore.subscriptions) { subscription in
            HStack(alignment: .top, spacing: 12) {
              NavigationLink {
                SubjectDetailScreen(subjectID: subscription.subjectID)
              } label: {
                HStack(alignment: .top, spacing: 12) {
                  CoverImage(url: subscription.coverURL)
                    .frame(width: 52, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                  VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                      Text(subscription.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                      if let subjectTypeTitle = subscription.subjectTypeTitle, !subjectTypeTitle.isEmpty {
                        Text(subjectTypeTitle)
                          .font(.caption.weight(.semibold))
                          .foregroundStyle(.secondary)
                          .padding(.horizontal, 8)
                          .padding(.vertical, 4)
                          .background(Color.secondary.opacity(0.12), in: Capsule())
                      }
                    }

                    if let subtitle = subscription.subtitle, !subtitle.isEmpty {
                      Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Text("当前基线：\(subscription.latestEpisodeLabel)")
                      .font(.caption)
                      .foregroundStyle(.secondary)

                    if let lastCheckedAt = subscription.lastCheckedAt {
                      Text("最近检查：\(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if let lastErrorMessage = subscription.lastErrorMessage, !lastErrorMessage.isEmpty {
                      Text(lastErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    }
                  }
                }
              }
              .buttonStyle(.plain)

              Spacer(minLength: 8)

              Toggle(
                "",
                isOn: Binding(
                  get: { notificationStore.subscription(for: subscription.subjectID) != nil },
                  set: { isOn in
                    if !isOn {
                      Task { @MainActor in
                        notificationStore.disableSubscription(subjectID: subscription.subjectID)
                      }
                    }
                  }
                )
              )
              .labelsHidden()
            }
            .padding(.vertical, 4)
          }
        }
      }

      if !notificationStore.subscriptions.isEmpty {
        Section {
          Button("全部关闭提醒", role: .destructive) {
            notificationStore.disableAllSubscriptions()
          }
        }
      }

      Section("Bangumi") {
        Button("打开站内通知网页") {
          model.presentedRoute = .web(URL(string: "https://bgm.tv/notify")!, "Bangumi 通知")
        }
      }
    }
    .navigationTitle("通知管理")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showsDismissButton {
        ToolbarItem(placement: .topBarLeading) {
          Button("关闭") {
            dismiss()
          }
        }
      }
    }
    .bangumiRootScrollableLayout()
  }
}

private struct MeScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @StateObject private var viewModel = MeViewModel()

  var body: some View {
    ScreenScaffold(
      title: "我的",
      subtitle: "会话、收藏概览、主题与缓存管理。",
      navigationBarStyle: .discoveryNative
    ) {
      List {
        Section("账号") {
          if let user = sessionStore.currentUser {
            NavigationLink {
              UserProfileScreen(userID: user.username)
            } label: {
              HStack(spacing: 12) {
                CoverImage(url: user.avatar?.best)
                  .frame(width: 56, height: 56)
                  .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                  Text(user.displayName)
                    .font(.headline)
                  Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
              }
            }

            Button("刷新资料") {
              Task {
                await viewModel.refresh(using: model.userRepository)
              }
            }

            Button("退出登录", role: .destructive) {
              sessionStore.signOut()
              viewModel.collections = []
            }
          } else {
            Button("登录 Bangumi") {
              model.isShowingLogin = true
            }
          }

          if let error = viewModel.errorMessage {
            Text(error)
              .foregroundStyle(.red)
          }
        }

        Section("设置") {
          NavigationLink {
            NotificationManagementScreen()
          } label: {
            Label("通知管理", systemImage: "bell.badge")
          }

          Picker("主题", selection: $settingsStore.preferredTheme) {
            ForEach(PreferredTheme.allCases) { theme in
              Text(theme.title).tag(theme)
            }
          }

          Button("清理缓存") {
            model.apiClient.clearCaches()
          }
        }

        if !viewModel.collections.isEmpty {
          Section("在看动画") {
            ForEach(viewModel.collections) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.subjectID)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.subject.nameCN ?? item.subject.name)
                  if let epStatus = item.epStatus {
                    Text("已追到第 \(epStatus) 集")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
        }

        Section("关于") {
          Text("当前原生版本已经接管 SwiftUI 根视图、认证骨架、时间线、发现、Rakuen、搜索、条目详情、账号与设置。")
            .font(.footnote)
          Text("下一步优先补富文本渲染、发帖交互和更稳的离线缓存。")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("条目详情页排版使用了 MiSans 字体。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .bangumiRootScrollableLayout()
      .task {
        await viewModel.bootstrap(using: model.userRepository, sessionStore: sessionStore)
      }
    }
  }
}

private final class MeViewModel: ObservableObject {
  @Published var collections: [BangumiCollectionItem] = []
  @Published var errorMessage: String?

  @MainActor
  func bootstrap(using repository: UserRepository, sessionStore: BangumiSessionStore) async {
    guard sessionStore.isAuthenticated else {
      collections = []
      errorMessage = nil
      return
    }

    await refresh(using: repository)
  }

  @MainActor
  func refresh(using repository: UserRepository) async {
    do {
      _ = try await repository.refreshCurrentUser()
      collections = try await repository.fetchWatchingCollections()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct LoginScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @Environment(\.dismiss) private var dismiss
  @State private var manualToken = ""
  @State private var isLoading = false
  @State private var isShowingOAuthWebLogin = false
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("OAuth") {
        Text("Bangumi 当前应用注册的是网页回调地址，这里改成和原版一致的网页登录流程。登录并授权后会自动回到应用内完成登录。")
          .font(.footnote)
          .foregroundStyle(.secondary)

        Button(isLoading ? "登录中..." : "开始网页登录") {
          errorMessage = nil
          isShowingOAuthWebLogin = true
        }
        .disabled(isLoading)
      }

      Section("手动 Token") {
        TextField("粘贴 Access Token", text: $manualToken)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        Button("使用 Token 登录") {
          Task {
            await signInWithToken()
          }
        }
        .disabled(isLoading || manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if let errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("登录")
    .navigationDestination(isPresented: $isShowingOAuthWebLogin) {
      OAuthLoginScreen(
        authorizeURL: model.apiClient.makeAuthorizeURL(),
        callbackURL: model.apiClient.config.callbackURL,
        onCode: { code in
          isShowingOAuthWebLogin = false
          Task {
            await signInWithOAuthCode(code)
          }
        },
        onFailure: { message in
          isShowingOAuthWebLogin = false
          errorMessage = message
        }
      )
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("关闭") {
          dismiss()
        }
      }
    }
  }

  @MainActor
  private func signInWithOAuthCode(_ code: String) async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await model.authService.signInWithAuthorizationCode(code)
      errorMessage = nil
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func signInWithToken() async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await model.authService.signInWithToken(manualToken)
      errorMessage = nil
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct OAuthLoginScreen: View {
  let authorizeURL: URL
  let callbackURL: URL
  let onCode: @MainActor (String) -> Void
  let onFailure: @MainActor (String) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      Text("登录 Bangumi 并在授权页点“授权”，应用会在检测到回调地址后自动完成登录。")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()

      BangumiOAuthWebView(
        authorizeURL: authorizeURL,
        callbackURL: callbackURL,
        onCode: onCode,
        onFailure: onFailure
      )
    }
    .navigationTitle("网页登录")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("取消") {
          dismiss()
        }
      }
    }
  }
}

private struct WebFallbackScreen: View {
  let title: String
  let subtitle: String?
  let url: URL?

  var body: some View {
    VStack(spacing: 0) {
      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
      }

      if let url {
        BangumiWebView(url: url)
      } else {
        UnavailableStateView(
          title: "地址不可用",
          systemImage: "safari",
          message: "请稍后再试。"
        )
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct UnavailableStateView: View {
  let title: String
  let systemImage: String
  let message: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

private struct BangumiWebView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if webView.url != url {
      webView.load(URLRequest(url: url))
    }
  }
}

private struct BangumiOAuthWebView: UIViewRepresentable {
  let authorizeURL: URL
  let callbackURL: URL
  let onCode: @MainActor (String) -> Void
  let onFailure: @MainActor (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    configuration.websiteDataStore = .default()

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.load(URLRequest(url: authorizeURL))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if webView.url == nil {
      webView.load(URLRequest(url: authorizeURL))
    }
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    private let parent: BangumiOAuthWebView
    private var hasHandledCallback = false
    private var hasRecoveredAuthorizeURL = false

    init(_ parent: BangumiOAuthWebView) {
      self.parent = parent
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }

      if shouldRecoverAuthorizeURL(url) {
        decisionHandler(.cancel)
        recoverAuthorizeURL(in: webView)
        return
      }

      guard isOAuthCallback(url) else {
        decisionHandler(.allow)
        return
      }

      decisionHandler(.cancel)
      handleOAuthCallback(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let url = webView.url else { return }

      if shouldRecoverAuthorizeURL(url) {
        recoverAuthorizeURL(in: webView)
        return
      }

      if isOAuthCallback(url) {
        handleOAuthCallback(url)
      }
    }

    private func isOAuthCallback(_ url: URL) -> Bool {
      url.host?.lowercased() == parent.callbackURL.host?.lowercased()
        && url.path == parent.callbackURL.path
    }

    private func shouldRecoverAuthorizeURL(_ url: URL) -> Bool {
      guard !hasRecoveredAuthorizeURL else { return false }
      guard url.host?.lowercased() == parent.authorizeURL.host?.lowercased() else { return false }
      guard url.path == parent.authorizeURL.path else { return false }

      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let hasRedirectURI = components?.queryItems?.contains(where: { $0.name == "redirect_uri" }) ?? false
      return !hasRedirectURI
    }

    private func recoverAuthorizeURL(in webView: WKWebView) {
      guard !hasRecoveredAuthorizeURL else { return }
      hasRecoveredAuthorizeURL = true
      webView.load(URLRequest(url: parent.authorizeURL))
    }

    private func handleOAuthCallback(_ url: URL) {
      guard !hasHandledCallback else { return }
      hasHandledCallback = true

      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
         !code.isEmpty {
        Task { @MainActor in
          parent.onCode(code)
        }
        return
      }

      let errorMessage = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
        ?? components?.queryItems?.first(where: { $0.name == "error" })?.value
        ?? BangumiError.oauthMissingCode.localizedDescription

      Task { @MainActor in
        parent.onFailure(errorMessage)
      }
    }
  }
}

private struct SubjectRow: View {
  let item: BangumiSubjectSummary

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      CoverImage(url: item.images?.best)
        .frame(width: 56, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 6) {
        Text(item.nameCN ?? item.name)
          .font(.headline)
          .foregroundStyle(.primary)

        if let nameCN = item.nameCN, nameCN != item.name {
          Text(item.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 12) {
          if let score = item.rating?.score {
            Text("评分 \(score, specifier: "%.1f")")
          }
          if let totalEpisodes = item.totalEpisodes ?? item.eps {
            Text("\(totalEpisodes) 集")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct CoverImage: View {
  let url: URL?

  var body: some View {
    AsyncImage(url: url) { image in
      image
        .resizable()
        .scaledToFill()
    } placeholder: {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.secondary.opacity(0.15))
        Image(systemName: "photo")
          .foregroundStyle(.secondary)
      }
    }
  }
}
