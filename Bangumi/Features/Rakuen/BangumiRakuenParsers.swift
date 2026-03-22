import Foundation

enum BangumiRakuenParser {
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

enum BangumiRakuenTopicParser {
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

