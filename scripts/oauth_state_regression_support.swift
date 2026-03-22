import Foundation

enum PreferredTheme: String {
  case system
}

enum SubjectType: Int {
  case anime = 2
  case book = 1
  case real = 6
  case game = 4
}

enum CollectionStatus: String {
  case doing

  var v0Type: String { "3" }
}

enum TimelineFilter: String {
  case all
}

enum RakuenFilter: String {
  case all
}

struct BangumiCollectionItem: Codable, Identifiable {
  let id: Int
}

struct BangumiSubjectCollectionRecord: Codable {
  var type: String?
  var rate: Int?
  var tags: [String]?
  var comment: String?
  var epStatus: Int?
  var volStatus: Int?
}

struct BangumiSubjectComment: Codable, Identifiable {
  let id: Int
}

struct BangumiSubjectPresentation: Codable {
  static let empty = BangumiSubjectPresentation()
}

struct CollectionUpdatePayload {
  let status: CollectionStatus
  let rating: Int
  let tags: String
  let comment: String
  let isPrivate: Bool
  let watchedEpisodes: Int?
  let watchedVolumes: Int?
}

struct BangumiV0SubjectDTO: Codable {
  func subject() -> BangumiSubject {
    BangumiSubject(
      id: 0,
      type: nil,
      name: "",
      nameCN: nil,
      summary: nil,
      images: nil,
      eps: nil,
      totalEpisodes: nil,
      volumes: nil,
      platform: nil,
      date: nil,
      rating: nil,
      tags: nil,
      locked: nil,
      nsfw: nil,
      collection: nil
    )
  }
}

struct BangumiV0EpisodesResponse: Codable {
  let data: [BangumiEpisodeDTO]
}

struct BangumiEpisodeDTO: Codable {
  func episode() -> BangumiEpisode {
    BangumiEpisode(id: 0, name: nil, nameCN: nil, sort: nil, airdate: nil, status: nil)
  }
}

struct BangumiUserProfile: Codable {}
struct BangumiTimelinePage: Codable {}
struct BangumiTimelineDetail: Codable {}
struct BangumiRakuenItem: Codable, Identifiable {
  let id: String
}
struct BangumiRakuenTopicDetail: Codable {}

enum BangumiSubjectSearchWebParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectSummary] { [] }
}

enum BangumiSubjectWebParser {
  static func parse(html: String, id: Int, baseURL: URL) -> BangumiSubject {
    BangumiSubject(
      id: id,
      type: nil,
      name: "",
      nameCN: nil,
      summary: nil,
      images: nil,
      eps: nil,
      totalEpisodes: nil,
      volumes: nil,
      platform: nil,
      date: nil,
      rating: nil,
      tags: nil,
      locked: nil,
      nsfw: nil,
      collection: nil
    )
  }

  static func parseEpisodes(html: String) -> [BangumiEpisode] { [] }
}

enum BangumiSubjectCommentsParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectComment] { [] }
}

enum BangumiSubjectPresentationParser {
  static func parse(
    subjectHTML: String,
    charactersHTML: String?,
    staffHTML: String?,
    relationsHTML: String?,
    subjectID: Int,
    baseURL: URL
  ) -> BangumiSubjectPresentation {
    .empty
  }
}

enum BangumiUserProfileParser {
  static func parse(html: String, userID: String, baseURL: URL) -> BangumiUserProfile { BangumiUserProfile() }
}

enum BangumiTimelineParser {
  static func parse(html: String, page: Int, baseURL: URL) -> BangumiTimelinePage { BangumiTimelinePage() }
}

enum BangumiTimelineDetailParser {
  static func parse(html: String, baseURL: URL) -> BangumiTimelineDetail { BangumiTimelineDetail() }
}

enum BangumiRakuenParser {
  static func parse(html: String, baseURL: URL) -> [BangumiRakuenItem] { [] }
}

enum BangumiRakuenTopicParser {
  static func parse(html: String, baseURL: URL) -> BangumiRakuenTopicDetail { BangumiRakuenTopicDetail() }
}
