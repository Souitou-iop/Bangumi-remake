import Foundation
import SwiftUI

enum BangumiTab: Hashable {
  case home
  case discovery
  case rakuen
  case me
}

enum HomeCategory: String, CaseIterable, Identifiable {
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

enum PreferredTheme: String, CaseIterable, Identifiable {
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

enum SubjectType: Int, CaseIterable, Identifiable {
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

enum BangumiSearchMatchMode: String, CaseIterable, Identifiable {
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

struct BangumiSearchQuery: Hashable {
  let keyword: String
  let type: SubjectType
  let matchMode: BangumiSearchMatchMode
}

enum CollectionStatus: String, CaseIterable, Identifiable {
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

enum TimelineFilter: String, CaseIterable, Identifiable {
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

enum RakuenFilter: String, CaseIterable, Identifiable {
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

struct BangumiImagePreview: Identifiable {
  let url: URL

  var id: String { url.absoluteString }
}

enum BangumiModalRoute: Identifiable {
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
