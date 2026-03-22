import Foundation

enum BangumiSubjectSearchWebParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectSummary] {
    guard let listHTML = BangumiHTMLParser.extractSection(
      in: html,
      start: #"<ul id="browserItemList""#,
      end: "</ul>"
    ) else {
      return []
    }

    return BangumiHTMLParser.matches(
      in: listHTML,
      pattern: #"<li id="item_\d+" class="item.*?</li>"#
    ).compactMap { match -> BangumiSubjectSummary? in
      guard let block = BangumiHTMLParser.capture(listHTML, from: match, group: 0) else {
        return nil
      }

      let href = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="(/subject/\d+)" class="subjectCover"#
      )
      guard let id = BangumiHTMLParser.subjectID(from: href) else {
        return nil
      }

      let titleHTML = BangumiHTMLParser.firstCapture(in: block, pattern: #"<h3>(.*?)</h3>"#) ?? block
      let localizedTitle = BangumiHTMLParser.firstCapture(
        in: titleHTML,
        pattern: #"<a href="/subject/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !localizedTitle.isEmpty else { return nil }

      let originalTitle = BangumiHTMLParser.firstCapture(
        in: titleHTML,
        pattern: #"<small class="grey">(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags)
      let type = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"subject_type_(\d+)"#
      ).flatMap(Int.init)
      let cover = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<img src="([^"]+)""#
      )
      let rank = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"Rank </small>\s*(\d+)"#
      ).flatMap(Int.init)
      let meta = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<p class="info tip">\s*(.*?)\s*</p>"#
      ).map(BangumiHTMLParser.stripTags)
      let score = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="fade">([\d.]+)</small>"#
      ).flatMap(Double.init)
      let total = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"\((\d+)人评分\)"#
      ).flatMap(Int.init)
      let date = meta.flatMap(firstSearchDate(in:))
      let coverURL = BangumiHTMLParser.absoluteURL(from: cover, baseURL: baseURL)?.absoluteString

      return BangumiSubjectSummary(
        id: id,
        type: type,
        name: originalTitle ?? localizedTitle,
        nameCN: localizedTitle,
        images: BangumiImages(
          large: coverURL,
          common: coverURL,
          medium: coverURL,
          small: coverURL
        ),
        eps: nil,
        totalEpisodes: nil,
        date: date,
        rating: BangumiRating(
          score: score,
          rank: rank,
          total: total
        ),
        searchMeta: meta
      )
    }
  }

  private static func firstSearchDate(in text: String) -> String? {
    guard
      let match = BangumiHTMLParser.matches(
        in: text,
        pattern: #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
      ).first,
      let year = BangumiHTMLParser.capture(text, from: match, group: 1),
      let month = BangumiHTMLParser.capture(text, from: match, group: 2).flatMap(Int.init),
      let day = BangumiHTMLParser.capture(text, from: match, group: 3).flatMap(Int.init)
    else {
      return nil
    }

    return String(format: "%@-%02d-%02d", year, month, day)
  }
}

enum BangumiSubjectWebParser {
  static func parse(html: String, id: Int, baseURL: URL) -> BangumiSubject {
    let titleHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<h1[^>]*class="nameSingle"[^>]*>(.*?)</h1>"#
    ) ?? ""
    let chineseName = BangumiHTMLParser.firstCapture(
      in: titleHTML,
      pattern: #"<a[^>]*title="([^"]+)""#
    ).map(BangumiHTMLParser.decodeEntities)
    let primaryName = BangumiHTMLParser.firstCapture(
      in: titleHTML,
      pattern: #"<a[^>]*>(.*?)</a>"#
    ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 条目"

    let summaryHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<div id="subject_summary"[^>]*>(.*?)</div>"#
    ) ?? ""
    let summary = BangumiHTMLParser.stripTags(summaryHTML)

    let coverURL = BangumiHTMLParser.absoluteURL(
      from: BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<img[^>]*class="cover"[^>]*src="([^"]+)""#
      ),
      baseURL: baseURL
    )?.absoluteString

    let score = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="number">([\d.]+)</span>"#
    ).flatMap(Double.init)
    let rank = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"排名[^#]*#(\d+)"#
    ).flatMap(Int.init)
    let total = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="tip_j">\((\d+)\)</span>"#
    ).flatMap(Int.init)

    let infoboxHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<ul id="infobox">(.*?)</ul>"#
    ) ?? ""
    let eps = metadataValue(in: infoboxHTML, labels: ["话数", "集数"]).flatMap(Int.init)
    let totalEpisodes = eps
    let volumes = metadataValue(in: infoboxHTML, labels: ["卷数"]).flatMap(Int.init)
    let platform = metadataValue(in: infoboxHTML, labels: ["平台"])
    let date = metadataValue(in: infoboxHTML, labels: ["放送开始", "发售日", "上映年度", "开始", "日期"])

    let tags: [BangumiTag] = BangumiHTMLParser.matches(
      in: html,
      pattern: #"<a[^>]*class="l[^"]*"[^>]*><span>(.*?)</span><small>(.*?)</small></a>"#
    ).compactMap { match in
      guard
        let name = BangumiHTMLParser.capture(html, from: match, group: 1).map(BangumiHTMLParser.stripTags),
        !name.isEmpty
      else {
        return nil
      }

      let count = BangumiHTMLParser.capture(html, from: match, group: 2)
        .map(BangumiHTMLParser.stripTags)
        .flatMap(Int.init)
      return BangumiTag(name: name, count: count)
    }

    return BangumiSubject(
      id: id,
      type: metadataSubjectType(in: html),
      name: primaryName,
      nameCN: chineseName,
      summary: summary.isEmpty ? nil : summary,
      images: BangumiImages(large: coverURL, common: coverURL, medium: coverURL, small: coverURL),
      eps: eps,
      totalEpisodes: totalEpisodes,
      volumes: volumes,
      platform: platform,
      date: date,
      rating: BangumiRating(score: score, rank: rank, total: total),
      tags: tags.isEmpty ? nil : tags,
      locked: nil,
      nsfw: nil,
      collection: nil
    )
  }

  static func parseEpisodes(html: String) -> [BangumiEpisode] {
    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<li class="episode"#)
    return blocks.compactMap { block in
      guard let id = BangumiHTMLParser.firstCapture(in: block, pattern: #"data-ep-id="(\d+)""#).flatMap(Int.init) ??
        BangumiHTMLParser.firstCapture(in: block, pattern: #"/ep/(\d+)"#).flatMap(Int.init) else {
        return nil
      }

      let sort = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="epAirStatus[^"]*">\s*EP\.?(\d+(?:\.\d+)?)"#
      ).flatMap(Double.init) ?? BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small[^>]*>(\d+(?:\.\d+)?)</small>"#
      ).flatMap(Double.init)

      let nameCN = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="l ep_status"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags)
      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="tip"[^>]*>(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let airdate = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="tip_j">\((.*?)\)</span>"#
      ).map(BangumiHTMLParser.stripTags)

      return BangumiEpisode(
        id: id,
        name: name,
        nameCN: nameCN,
        sort: sort,
        airdate: airdate,
        status: (nameCN?.isEmpty == false || name?.isEmpty == false) ? "Air" : "NA"
      )
    }
    .sorted { lhs, rhs in
      (lhs.sort ?? .greatestFiniteMagnitude) < (rhs.sort ?? .greatestFiniteMagnitude)
    }
  }

  private static func metadataValue(in infoboxHTML: String, labels: [String]) -> String? {
    for label in labels {
      let escapedLabel = NSRegularExpression.escapedPattern(for: label)
      let pattern = "<li>\\s*<span>\(escapedLabel):\\s*</span>(.*?)</li>"
      if let value = BangumiHTMLParser.firstCapture(
        in: infoboxHTML,
        pattern: pattern
      ) {
        let normalized = BangumiHTMLParser.stripTags(value)
        if !normalized.isEmpty {
          return normalized
        }
      }
    }
    return nil
  }

  private static func metadataSubjectType(in html: String) -> Int? {
    let typeText = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<small class="grey">(.*?)</small>"#
    ).map(BangumiHTMLParser.stripTags) ?? ""

    if typeText.contains("书籍") {
      return SubjectType.book.rawValue
    }
    if typeText.contains("动画") {
      return SubjectType.anime.rawValue
    }
    if typeText.contains("音乐") {
      return SubjectType.music.rawValue
    }
    if typeText.contains("游戏") {
      return SubjectType.game.rawValue
    }
    if typeText.contains("三次元") {
      return SubjectType.real.rawValue
    }
    return nil
  }
}

enum BangumiSubjectCommentsParser {
  static func parse(html: String, baseURL: URL) -> [BangumiSubjectComment] {
    let commentBox =
      BangumiHTMLParser.extractSection(
        in: html,
        start: #"<div id="comment_box""#,
        end: #"<template id="likes_reaction_grid_item""#
      ) ??
      BangumiHTMLParser.extractSection(
        in: html,
        start: #"<div id="comment_box""#,
        end: #"<div id="footer">"#
      ) ??
      ""

    let blocks = BangumiHTMLParser.splitBlocks(in: commentBox, marker: #"<div class="item clearit""#)
    return blocks.compactMap { block in
      let messageHTML = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<p class="comment">(.*?)</p>"#
      ) ?? ""
      let message = BangumiHTMLParser.stripTags(messageHTML)

      guard !message.isEmpty else { return nil }

      let greyTexts = BangumiHTMLParser.matches(
        in: block,
        pattern: #"<small[^>]*class="grey"[^>]*>(.*?)</small>"#
      )
      .compactMap { BangumiHTMLParser.capture(block, from: $0, group: 1) }
      .map(BangumiHTMLParser.stripTags)
      .filter { !$0.isEmpty }

      let userSign = greyTexts.first { !$0.contains("@") }
      let time = greyTexts.first { $0.contains("@") }?
        .replacingOccurrences(of: "@", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      let userID = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*href="/user/([^"/]+)""#
      )
      let userName = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a[^>]*class="l"[^>]*>(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? "Bangumi 用户"

      let avatarURL = BangumiHTMLParser.parseAvatarURLFromHTML(block, baseURL: baseURL)

      let identity = userID ?? BangumiHTMLParser.collapseWhitespace(userName)
      let identifier = [identity, time, message]
        .joined(separator: "|")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return BangumiSubjectComment(
        id: identifier.isEmpty ? UUID().uuidString : identifier,
        userName: userName,
        userID: userID,
        userSign: userSign,
        avatarURL: avatarURL,
        time: time,
        message: message,
        htmlMessage: messageHTML.isEmpty ? nil : messageHTML
      )
    }
  }
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
    let infoEntries = parseInfoEntries(html: subjectHTML)
    let parsedStaff = parseStaff(html: staffHTML, baseURL: baseURL)

    return BangumiSubjectPresentation(
      previews: parsePreviews(html: subjectHTML, baseURL: baseURL),
      infoEntries: infoEntries,
      ratingBreakdown: parseRatingBreakdown(html: subjectHTML),
      cast: parseCast(html: charactersHTML, baseURL: baseURL),
      staff: parsedStaff.isEmpty ? parseStaffFallback(from: infoEntries, baseURL: baseURL) : parsedStaff,
      relations: parseRelations(html: relationsHTML, baseURL: baseURL),
      morePreviewsURL: nil,
      moreCastURL: URL(string: "/subject/\(subjectID)/characters", relativeTo: baseURL)?.absoluteURL,
      moreStaffURL: URL(string: "/subject/\(subjectID)/persons?group=person", relativeTo: baseURL)?.absoluteURL,
      moreRelationsURL: URL(string: "/subject/\(subjectID)/relations", relativeTo: baseURL)?.absoluteURL,
      statsURL: URL(string: "/subject/\(subjectID)/stats", relativeTo: baseURL)?.absoluteURL
    )
  }

  private static func parsePreviews(html: String, baseURL: URL) -> [BangumiSubjectPreviewItem] {
    let candidateTitles = ["预览", "图集", "截图", "相册", "剧照"]
    for title in candidateTitles {
      if let section = BangumiHTMLParser.firstCapture(
        in: html,
        pattern: #"<h2 class="subtitle">\#(title)</h2>(.*?)(?=<h2 class="subtitle"|<div id="footer">)"#
      ) {
        let items = BangumiHTMLParser.matches(
          in: section,
          pattern: #"<a[^>]*href="([^"]+)"[^>]*>(?:<span[^>]*style="[^"]*url\(([^)]+)\)[^"]*"[^>]*>|<img[^>]*src="([^"]+)")[\s\S]*?</a>"#
        ).compactMap { match -> BangumiSubjectPreviewItem? in
          let href = BangumiHTMLParser.capture(section, from: match, group: 1)
          let imageSource = BangumiHTMLParser.capture(section, from: match, group: 2) ??
            BangumiHTMLParser.capture(section, from: match, group: 3)
          let title = BangumiHTMLParser.decodeEntities(
            BangumiHTMLParser.firstCapture(
              in: BangumiHTMLParser.capture(section, from: match, group: 0) ?? "",
              pattern: #"title="([^"]+)""#
            ) ?? ""
          )
          let url = BangumiHTMLParser.absoluteURL(from: href, baseURL: baseURL)
          let imageURL = BangumiHTMLParser.absoluteURL(
            from: imageSource?.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: ""),
            baseURL: baseURL
          )
          guard url != nil || imageURL != nil else { return nil }
          return BangumiSubjectPreviewItem(
            id: href ?? UUID().uuidString,
            title: title.isEmpty ? "图集" : title,
            caption: nil,
            imageURL: imageURL,
            targetURL: url
          )
        }
        if !items.isEmpty {
          return Array(items.prefix(8))
        }
      }
    }

    return []
  }

  private static func parseInfoEntries(html: String) -> [BangumiSubjectInfoEntry] {
    guard let infoboxHTML = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<ul id="infobox">(.*?)</ul>"#
    ) else {
      return []
    }

    return BangumiHTMLParser.matches(
      in: infoboxHTML,
      pattern: #"<li[^>]*>\s*<span class="tip">(.*?)</span>\s*(.*?)</li>"#
    ).compactMap { match in
      let label = BangumiHTMLParser.capture(infoboxHTML, from: match, group: 1)
        .map(BangumiHTMLParser.stripTags)?
        .replacingOccurrences(of: "：", with: "")
        .replacingOccurrences(of: ":", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let valueHTML = BangumiHTMLParser.capture(infoboxHTML, from: match, group: 2)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let valueText = valueHTML.map(BangumiHTMLParser.stripTags) ?? ""
      guard !label.isEmpty, !valueText.isEmpty else { return nil }
      return BangumiSubjectInfoEntry(
        id: "\(label)|\(valueText.prefix(24))",
        label: label,
        textValue: valueText,
        htmlValue: valueHTML
      )
    }
  }

  private static func parseRatingBreakdown(html: String) -> BangumiSubjectRatingBreakdown? {
    let average = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span class="number"[^>]*>([\d.]+)</span>"#
    ).flatMap(Double.init)
    let rank = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"Bangumi [A-Za-z]+ Ranked:</small><small class="alarm">#(\d+)"#
    ).flatMap(Int.init) ?? BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"排名[^#]*#(\d+)"#
    ).flatMap(Int.init)
    let totalVotes = BangumiHTMLParser.firstCapture(
      in: html,
      pattern: #"<span property="v:votes">(\d+)</span>"#
    ).flatMap(Int.init)

    let buckets = BangumiHTMLParser.matches(
      in: html,
      pattern: #"<li><a[^>]*title="[^"]*"[^>]*><span class="label">(\d+)</span><span class="count"[^>]*>\((\d+)\)</span></a></li>"#
    ).compactMap { match -> BangumiSubjectRatingBucket? in
      guard
        let score = BangumiHTMLParser.capture(html, from: match, group: 1).flatMap(Int.init),
        let count = BangumiHTMLParser.capture(html, from: match, group: 2).flatMap(Int.init)
      else {
        return nil
      }
      return BangumiSubjectRatingBucket(score: score, count: count)
    }
    .sorted { $0.score > $1.score }

    let externalRatings = BangumiHTMLParser.matches(
      in: html,
      pattern: #"([A-Za-z][A-Za-z0-9]+):\s*([\d.]+)(?:\s*\((\d+)\))?"#
    ).compactMap { match -> BangumiSubjectExternalRating? in
      let source = BangumiHTMLParser.capture(html, from: match, group: 1) ?? ""
      guard ["VIB", "AniDB", "MAL", "IMDb", "Douban"].contains(source) else { return nil }
      let scoreText = BangumiHTMLParser.capture(html, from: match, group: 2) ?? ""
      let votes = BangumiHTMLParser.capture(html, from: match, group: 3)
      return BangumiSubjectExternalRating(
        source: source,
        scoreText: scoreText,
        votesText: votes
      )
    }

    guard average != nil || totalVotes != nil || !buckets.isEmpty else { return nil }
    return BangumiSubjectRatingBreakdown(
      average: average,
      rank: rank,
      totalVotes: totalVotes,
      buckets: buckets,
      externalRatings: externalRatings
    )
  }

  private static func parseCast(html: String?, baseURL: URL) -> [BangumiSubjectCastItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<a name="id_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/character/\d+)""#) else {
        return nil
      }

      let detailURL = BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL)
      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<a href="/character/\d+" class="avatar"><img src="([^"]+)""#
        ),
        baseURL: baseURL
      )

      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/character/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !name.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle">.*?<span class="tip">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let role = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="badge_job_tip badge_job"[^>]*>(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let actorName = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<div class="actorBadge.*?<p><a href="/person/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags)
      let accentText = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="primary">\((\+\d+)\)</small>"#
      )

      return BangumiSubjectCastItem(
        id: detailHref,
        name: name,
        subtitle: subtitle,
        role: role,
        actorName: actorName,
        accentText: accentText,
        imageURL: imageURL,
        detailURL: detailURL
      )
    }
    .prefix(12)
    .map { $0 }
  }

  private static func parseStaff(html: String?, baseURL: URL) -> [BangumiSubjectStaffItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<a name="id_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/person/\d+)""#) else {
        return nil
      }

      let name = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/person/\d+">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !name.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<h2 class="subtitle"><a href="/person/\d+">.*?<span class="tip">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)

      let roles = BangumiHTMLParser.matches(
        in: block,
        pattern: #"<span class="badge_job">(.*?)</span>"#
      )
      .compactMap { BangumiHTMLParser.capture(block, from: $0, group: 1).map(BangumiHTMLParser.stripTags) }
      .filter { !$0.isEmpty }
      .joined(separator: " · ")

      let credit = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<div class="prsn_info">\s*<span class="tip">\s*(.*?)</span>\s*</div>"#
      ).map(BangumiHTMLParser.stripTags)

      let accentText = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="orange">\((\+\d+)\)</small>"#
      )

      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<(?:a href="/person/\d+" class="avatar"><img|img)[^>]*src="([^"]+)""#
        ),
        baseURL: baseURL
      )

      return BangumiSubjectStaffItem(
        id: detailHref,
        name: name,
        subtitle: subtitle,
        roles: roles.isEmpty ? "制作人员" : roles,
        credit: credit,
        accentText: accentText,
        imageURL: imageURL,
        detailURL: BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL)
      )
    }
    .prefix(12)
    .map { $0 }
  }

  private static func parseStaffFallback(
    from entries: [BangumiSubjectInfoEntry],
    baseURL: URL
  ) -> [BangumiSubjectStaffItem] {
    var seen = Set<String>()
    var items: [BangumiSubjectStaffItem] = []

    for entry in entries {
      let anchors = BangumiHTMLParser.anchors(in: entry.htmlValue ?? "")
        .filter { $0.href.contains("/person/") }

      guard !anchors.isEmpty else { continue }

      for anchor in anchors {
        let normalizedName = BangumiHTMLParser.collapseWhitespace(anchor.text)
        guard !normalizedName.isEmpty else { continue }

        let id = "\(entry.label)|\(anchor.href)"
        guard !seen.contains(id) else { continue }
        seen.insert(id)

        let subtitle = anchor.title
          .map(BangumiHTMLParser.collapseWhitespace)
          .flatMap { title in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == normalizedName ? nil : trimmed
          }

        items.append(
          BangumiSubjectStaffItem(
            id: id,
            name: normalizedName,
            subtitle: subtitle,
            roles: entry.label,
            credit: nil,
            accentText: nil,
            imageURL: nil,
            detailURL: BangumiHTMLParser.absoluteURL(from: anchor.href, baseURL: baseURL)
          )
        )
      }
    }

    return Array(items.prefix(12))
  }

  private static func parseRelations(html: String?, baseURL: URL) -> [BangumiSubjectRelationItem] {
    guard let html else { return [] }

    let blocks = BangumiHTMLParser.splitBlocks(in: html, marker: #"<li id="item_"#)
    return blocks.compactMap { block in
      guard let detailHref = BangumiHTMLParser.firstCapture(in: block, pattern: #"<a href="(/subject/\d+)""#) else {
        return nil
      }

      let title = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="/subject/\d+" class="l">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<a href="/subject/\d+" class="title">(.*?)</a>"#
      ).map(BangumiHTMLParser.stripTags) ?? ""
      guard !title.isEmpty else { return nil }

      let subtitle = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<small class="grey">(.*?)</small>"#
      ).map(BangumiHTMLParser.stripTags)
      let relationLabel = BangumiHTMLParser.firstCapture(
        in: block,
        pattern: #"<span class="sub">(.*?)</span>"#
      ).map(BangumiHTMLParser.stripTags)
      let imageURL = BangumiHTMLParser.absoluteURL(
        from: BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"<img src="([^"]+)""#
        ) ?? BangumiHTMLParser.firstCapture(
          in: block,
          pattern: #"background-image:url\((?:'|")?(.+?)(?:'|")?\)"#
        ),
        baseURL: baseURL
      )

      return BangumiSubjectRelationItem(
        id: detailHref,
        title: title,
        subtitle: subtitle,
        relationLabel: relationLabel?.isEmpty == true ? nil : relationLabel,
        imageURL: imageURL,
        detailURL: BangumiHTMLParser.absoluteURL(from: detailHref, baseURL: baseURL),
        subjectID: BangumiHTMLParser.subjectID(from: detailHref)
      )
    }
    .prefix(12)
    .map { $0 }
  }
}
