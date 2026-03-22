import Foundation
import SwiftUI

struct BangumiHTMLAnchor {
  let href: String
  let text: String
  let title: String?
}

enum BangumiHTMLParser {
  static func extractSection(in html: String, start: String, end: String) -> String? {
    guard let startRange = html.range(of: start) else { return nil }
    let remaining = html[startRange.upperBound...]
    guard let endRange = remaining.range(of: end) else { return nil }
    return String(remaining[..<endRange.lowerBound])
  }

  static func matches(in text: String, pattern: String) -> [NSTextCheckingResult] {
    guard let regex = try? NSRegularExpression(
      pattern: pattern,
      options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
      return []
    }

    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, options: [], range: range)
  }

  static func firstCapture(in text: String, pattern: String, group: Int = 1) -> String? {
    matches(in: text, pattern: pattern).first.flatMap { capture(text, from: $0, group: group) }
  }

  static func capture(_ text: String, from result: NSTextCheckingResult, group: Int) -> String? {
    guard group < result.numberOfRanges else { return nil }
    let range = result.range(at: group)
    guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
    return String(text[swiftRange])
  }

  static func splitBlocks(in text: String, marker: String) -> [String] {
    let parts = text.components(separatedBy: marker)
    guard parts.count > 1 else { return [] }

    return parts.dropFirst().map { marker + $0 }
  }

  static func stripTags(_ html: String) -> String {
    let withoutBreaks = html
      .replacingOccurrences(of: "<br ?/?>", with: "\n", options: .regularExpression)
      .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
      .replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
      .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    return decodeEntities(withoutBreaks)
  }

  static func decodeEntities(_ text: String) -> String {
    let data = Data(text.utf8)
    if let attributed = try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) {
      return collapseWhitespace(attributed.string)
    }

    let replacements = [
      "&nbsp;": " ",
      "&amp;": "&",
      "&quot;": "\"",
      "&#039;": "'",
      "&lt;": "<",
      "&gt;": ">"
    ]

    let normalized = replacements.reduce(text) { partialResult, pair in
      partialResult.replacingOccurrences(of: pair.key, with: pair.value)
    }
    return collapseWhitespace(normalized)
  }

  static func attributedString(from html: String, baseURL: URL) -> AttributedString? {
    let webPrefix = baseURL.absoluteString + "/"
    let normalizedHTML = mediaStrippedHTML(from: html)
      .replacingOccurrences(of: "href=\"/", with: "href=\"\(webPrefix)")
      .replacingOccurrences(of: "src=\"/", with: "src=\"\(webPrefix)")
    let wrappedHTML = """
    <html>
      <head>
        <meta charset="utf-8">
      </head>
      <body>\(normalizedHTML)</body>
    </html>
    """

    guard let data = wrappedHTML.data(using: .utf8) else { return nil }
    guard let attributed = try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) else {
      return nil
    }

    guard let swiftAttributed = try? AttributedString(attributed, including: \.uiKit) else {
      return nil
    }
    return swiftAttributed
  }

  static func mediaStrippedHTML(from html: String) -> String {
    html
      .replacingOccurrences(of: #"<img[^>]*>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"<blockquote[^>]*>.*?</blockquote>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"<div class="quote"[^>]*>.*?</div>"#, with: "", options: .regularExpression)
  }

  static func imageURLs(in html: String, baseURL: URL) -> [URL] {
    matches(in: html, pattern: #"<img[^>]*src="([^"]+)""#).compactMap { match in
      absoluteURL(from: capture(html, from: match, group: 1), baseURL: baseURL)
    }
  }

  static func quoteBlocks(in html: String) -> [String] {
    let blockquotes = matches(
      in: html,
      pattern: #"<blockquote[^>]*>(.*?)</blockquote>"#
    ).compactMap { match in
      capture(html, from: match, group: 1).map(stripTags)
    }

    let quoteDivs = matches(
      in: html,
      pattern: #"<div class="quote"[^>]*>(.*?)</div>"#
    ).compactMap { match in
      capture(html, from: match, group: 1).map(stripTags)
    }

    return Array(Set((blockquotes + quoteDivs).filter { !$0.isEmpty }))
  }

  static func collapseWhitespace(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "[\\t\\f\\v ]+", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\n\\s*\\n+", with: "\n", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func parseAvatarURL(from style: String, baseURL: URL) -> URL? {
    guard let value = firstCapture(
      in: style,
      pattern: #"url\((?:'|")?(.+?)(?:'|")?\)"#
    ) else {
      return nil
    }

    return absoluteURL(from: value, baseURL: baseURL)
  }

  static func parseAvatarURLFromHTML(_ html: String, baseURL: URL) -> URL? {
    let stylePatterns = [
      #"<(?:span|div|a)[^>]*class="[^"]*avatar[^"]*"[^>]*style="([^"]+)""#,
      #"<(?:span|div|a)[^>]*class='[^']*avatar[^']*'[^>]*style='([^']+)'"#,
      #"<(?:span|div|a)[^>]*style="([^"]*background-image\s*:\s*url\([^)]+\)[^"]*)""#,
      #"<(?:span|div|a)[^>]*style='([^']*background-image\s*:\s*url\([^)]+\)[^']*)'"#
    ]

    for pattern in stylePatterns {
      if let style = firstCapture(in: html, pattern: pattern),
         let url = parseAvatarURL(from: style, baseURL: baseURL) {
        return url
      }
    }

    let sourcePatterns = [
      #"<img[^>]*class="[^"]*avatar[^"]*"[^>]*src="([^"]+)""#,
      #"<img[^>]*class='[^']*avatar[^']*'[^>]*src='([^']+)'"#,
      #"<img[^>]*src="([^"]+)""#,
      #"<img[^>]*src='([^']+)'"#,
      #"<img[^>]*data-src="([^"]+)""#,
      #"<img[^>]*data-src='([^']+)'"#
    ]

    for pattern in sourcePatterns {
      if let source = firstCapture(in: html, pattern: pattern),
         let url = absoluteURL(from: source, baseURL: baseURL) {
        return url
      }
    }

    return nil
  }

  static func absoluteURL(from href: String?, baseURL: URL) -> URL? {
    guard let href, !href.isEmpty else { return nil }
    if let normalized = BangumiRemoteURL.url(from: href), normalized.scheme != nil {
      return normalized
    }
    if let url = URL(string: href), url.scheme != nil {
      return url
    }
    return URL(string: href, relativeTo: baseURL)?.absoluteURL
  }

  static func subjectID(from href: String?) -> Int? {
    guard let href else { return nil }
    guard let value = firstCapture(in: href, pattern: #"/subject/(\d+)"#) else { return nil }
    return Int(value)
  }

  static func anchors(in html: String) -> [BangumiHTMLAnchor] {
    matches(
      in: html,
      pattern: #"<a\b([^>]*?)href="([^"]+)"([^>]*)>(.*?)</a>"#
    ).compactMap { match in
      guard
        let beforeAttributes = capture(html, from: match, group: 1),
        let href = capture(html, from: match, group: 2),
        let afterAttributes = capture(html, from: match, group: 3),
        let innerHTML = capture(html, from: match, group: 4)
      else {
        return nil
      }

      let titleSource = beforeAttributes + afterAttributes
      let title = firstCapture(in: titleSource, pattern: #"title="([^"]+)""#)
      return BangumiHTMLAnchor(
        href: href,
        text: stripTags(innerHTML),
        title: title.map(decodeEntities)
      )
    }
  }
}
