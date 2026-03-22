import Foundation

struct BangumiUserProfile: Identifiable, Hashable {
  let username: String
  let displayName: String
  let avatarURL: URL?
  let sign: String?
  let bio: String?
  let joinedAt: String?
  let location: String?

  var id: String { username }
}
