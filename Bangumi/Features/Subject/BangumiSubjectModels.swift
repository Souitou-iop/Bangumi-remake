import Foundation

struct BangumiSubjectComment: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let userSign: String?
  let avatarURL: URL?
  let time: String
  let message: String
  let htmlMessage: String?
}

struct BangumiSubjectPresentation: Hashable {
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

struct BangumiSubjectPreviewItem: Identifiable, Hashable {
  let id: String
  let title: String
  let caption: String?
  let imageURL: URL?
  let targetURL: URL?
}

struct BangumiSubjectInfoEntry: Identifiable, Hashable {
  let id: String
  let label: String
  let textValue: String
  let htmlValue: String?
}

struct BangumiSubjectRatingBreakdown: Hashable {
  let average: Double?
  let rank: Int?
  let totalVotes: Int?
  let buckets: [BangumiSubjectRatingBucket]
  let externalRatings: [BangumiSubjectExternalRating]
}

struct BangumiSubjectRatingBucket: Identifiable, Hashable {
  let score: Int
  let count: Int

  var id: Int { score }
}

struct BangumiSubjectExternalRating: Identifiable, Hashable {
  let source: String
  let scoreText: String
  let votesText: String?

  var id: String { source }
}

struct BangumiSubjectCastItem: Identifiable, Hashable {
  let id: String
  let name: String
  let subtitle: String?
  let role: String?
  let actorName: String?
  let accentText: String?
  let imageURL: URL?
  let detailURL: URL?
}

struct BangumiSubjectStaffItem: Identifiable, Hashable {
  let id: String
  let name: String
  let subtitle: String?
  let roles: String
  let credit: String?
  let accentText: String?
  let imageURL: URL?
  let detailURL: URL?
}

struct BangumiSubjectRelationItem: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String?
  let relationLabel: String?
  let imageURL: URL?
  let detailURL: URL?
  let subjectID: Int?
}

struct BangumiV0SubjectDTO: Codable {
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

struct BangumiV0EpisodesResponse: Codable {
  let data: [BangumiV0EpisodeDTO]
}

struct BangumiV0EpisodeDTO: Codable {
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

struct BangumiSubjectCollectionRecord: Codable {
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

struct BangumiCollectionItem: Codable, Identifiable {
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

struct CollectionUpdatePayload {
  var status: CollectionStatus
  var rating: Int
  var tags: String
  var comment: String
  var isPrivate: Bool
  var watchedEpisodes: Int?
  var watchedVolumes: Int?
}
