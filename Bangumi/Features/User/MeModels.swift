import Foundation

enum MeCollectionSortOrder: String, CaseIterable, Identifiable {
  case updatedAt
  case title
  case score
  case airDate

  var id: String { rawValue }

  var title: String {
    switch self {
    case .updatedAt: "收藏时间"
    case .title: "标题"
    case .score: "评分"
    case .airDate: "放送日期"
    }
  }

  var systemImage: String {
    switch self {
    case .updatedAt: "clock.arrow.circlepath"
    case .title: "textformat.abc"
    case .score: "star"
    case .airDate: "calendar"
    }
  }
}

enum MeCollectionTag: Hashable, Identifiable {
  case all
  case year(String)
  case undated

  var id: String {
    switch self {
    case .all: "all"
    case let .year(value): "year-\(value)"
    case .undated: "undated"
    }
  }

  var title: String {
    switch self {
    case .all: "全部"
    case let .year(value): value
    case .undated: "未知"
    }
  }
}

struct MeStatusSummary: Identifiable {
  let status: CollectionStatus
  let count: Int

  var id: String { status.id }
}

struct MeCollectionBucket {
  var total: Int = 0
  var items: [BangumiCollectionItem] = []
  var nextOffset: Int = 0
  var isLoading = false
  var hasLoaded = false
  var canLoadMore = true
}

extension BangumiCollectionItem {
  var meDisplayTitle: String {
    let preferred = subject.nameCN?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let preferred, !preferred.isEmpty {
      return preferred
    }
    return subject.name
  }

  var meSecondaryTitle: String? {
    guard let nameCN = subject.nameCN?.trimmingCharacters(in: .whitespacesAndNewlines),
          !nameCN.isEmpty,
          nameCN != subject.name else {
      return nil
    }
    return subject.name
  }

  var meMetadataLine: String {
    let parts = [
      meEpisodeText,
      meAirDateText,
      meRatingText
    ]
      .compactMap { $0 }
      .filter { !$0.isEmpty }

    return parts.joined(separator: " / ")
  }

  var meEpisodeText: String? {
    if let epStatus, epStatus > 0 {
      return "追到 \(epStatus) 集"
    }

    if let totalEpisodes = subject.totalEpisodes ?? subject.eps, totalEpisodes > 0 {
      return "\(totalEpisodes) 集"
    }

    return nil
  }

  var meAirDateText: String? {
    guard let date = subject.date?.trimmingCharacters(in: .whitespacesAndNewlines),
          !date.isEmpty else {
      return nil
    }
    return date
  }

  var meRatingText: String? {
    guard let score = subject.score else { return nil }
    return "评分 \(String(format: "%.1f", score))"
  }

  var meUpdatedAtText: String? {
    guard let updatedAt = updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines),
          !updatedAt.isEmpty else {
      return nil
    }
    return updatedAt
  }

  var meYearTag: MeCollectionTag {
    guard let date = meAirDateText else { return .undated }
    let prefix = String(date.prefix(4))
    if prefix.count == 4, Int(prefix) != nil {
      return .year(prefix)
    }
    return .undated
  }
}
