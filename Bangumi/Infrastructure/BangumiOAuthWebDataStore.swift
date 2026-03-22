import Foundation
import WebKit

@MainActor
final class BangumiOAuthWebDataStore {
  private let websiteDataStore: WKWebsiteDataStore
  private let domains: [String]

  init(
    websiteDataStore: WKWebsiteDataStore? = nil,
    domains: [String] = ["bgm.tv", "bangumi.tv"]
  ) {
    self.websiteDataStore = websiteDataStore ?? .default()
    self.domains = domains.map { $0.lowercased() }
  }

  func clearBangumiOAuthWebsiteData() async {
    let records = await fetchRecords()
    let matchingRecords = records.filter { matchesDomain($0.displayName) }
    if !matchingRecords.isEmpty {
      await removeData(
        ofTypes: Set(WKWebsiteDataStore.allWebsiteDataTypes()),
        for: matchingRecords
      )
    }

    let cookies = await fetchCookies()
    for cookie in cookies where matchesDomain(cookie.domain) {
      await delete(cookie)
    }
  }

  private func matchesDomain(_ rawDomain: String) -> Bool {
    let normalized = rawDomain
      .lowercased()
      .trimmingCharacters(in: CharacterSet(charactersIn: "."))

    return domains.contains { domain in
      normalized == domain || normalized.hasSuffix(".\(domain)")
    }
  }

  private func fetchRecords() async -> [WKWebsiteDataRecord] {
    await withCheckedContinuation { continuation in
      websiteDataStore.fetchDataRecords(ofTypes: Set(WKWebsiteDataStore.allWebsiteDataTypes())) { records in
        continuation.resume(returning: records)
      }
    }
  }

  private func removeData(
    ofTypes dataTypes: Set<String>,
    for records: [WKWebsiteDataRecord]
  ) async {
    await withCheckedContinuation { continuation in
      websiteDataStore.removeData(ofTypes: dataTypes, for: records) {
        continuation.resume()
      }
    }
  }

  private func fetchCookies() async -> [HTTPCookie] {
    await withCheckedContinuation { continuation in
      websiteDataStore.httpCookieStore.getAllCookies { cookies in
        continuation.resume(returning: cookies)
      }
    }
  }

  private func delete(_ cookie: HTTPCookie) async {
    await withCheckedContinuation { continuation in
      websiteDataStore.httpCookieStore.delete(cookie) {
        continuation.resume()
      }
    }
  }
}
