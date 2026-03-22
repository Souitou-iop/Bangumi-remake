import Foundation

enum BangumiTimelineParser {
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

enum BangumiTimelineDetailParser {
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

