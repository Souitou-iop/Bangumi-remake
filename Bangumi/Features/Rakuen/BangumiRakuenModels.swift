import Foundation

struct BangumiRakuenSubReply: Identifiable, Hashable {
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

struct BangumiRakuenItem: Identifiable, Hashable {
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

struct BangumiRakuenTopicDetail {
  let topic: BangumiRakuenTopic
  let comments: [BangumiRakuenComment]
}

struct BangumiRakuenTopic: Hashable {
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

struct BangumiRakuenComment: Identifiable, Hashable {
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
