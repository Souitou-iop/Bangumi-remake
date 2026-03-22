import Foundation

struct BangumiTimelinePage {
  let items: [BangumiTimelineItem]
  let nextPage: Int?
}

struct BangumiTimelineItem: Identifiable, Hashable {
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

struct BangumiTimelineDetail {
  let main: BangumiTimelinePost
  let replies: [BangumiTimelinePost]
}

struct BangumiTimelinePost: Identifiable, Hashable {
  let id: String
  let userName: String
  let userID: String?
  let avatarURL: URL?
  let date: String
  let text: String
  let htmlText: String?
}
