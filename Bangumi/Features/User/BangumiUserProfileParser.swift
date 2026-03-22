import Foundation

enum BangumiUserProfileParser {
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
