import Foundation
import Security
import SwiftUI

final class BangumiKeychainStore {
  private let service = "tv.bangumi.czy0729.native.auth"

  func save(_ data: Data, for key: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]
    SecItemDelete(query as CFDictionary)

    let newItem: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecValueData: data
    ]
    SecItemAdd(newItem as CFDictionary, nil)
  }

  func load(for key: String) -> Data? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else { return nil }
    return item as? Data
  }

  func remove(for key: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]
    SecItemDelete(query as CFDictionary)
  }
}

final class BangumiSessionStore: ObservableObject {
  @Published private(set) var token: BangumiToken?
  @Published private(set) var currentUser: BangumiUser?

  private let keychain = BangumiKeychainStore()
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init() {
    restore()
  }

  var isAuthenticated: Bool {
    token != nil
  }

  func restore() {
    if let tokenData = keychain.load(for: "token"),
       let decodedToken = try? decoder.decode(BangumiToken.self, from: tokenData) {
      token = decodedToken
    }

    if let userData = keychain.load(for: "user"),
       let decodedUser = try? decoder.decode(BangumiUser.self, from: userData) {
      currentUser = decodedUser
    }
  }

  func update(token: BangumiToken, user: BangumiUser) {
    self.token = token
    currentUser = user

    if let tokenData = try? encoder.encode(token) {
      keychain.save(tokenData, for: "token")
    }
    if let userData = try? encoder.encode(user) {
      keychain.save(userData, for: "user")
    }
  }

  func signOut() {
    token = nil
    currentUser = nil
    keychain.remove(for: "token")
    keychain.remove(for: "user")
  }
}

final class BangumiSettingsStore: ObservableObject {
  @Published var preferredTheme: PreferredTheme {
    didSet {
      userDefaults.set(preferredTheme.rawValue, forKey: "native.preferredTheme")
    }
  }

  @Published private(set) var recentSearches: [String]

  private let userDefaults = UserDefaults.standard

  init() {
    preferredTheme = PreferredTheme(rawValue: userDefaults.string(forKey: "native.preferredTheme") ?? "") ?? .system
    recentSearches = userDefaults.stringArray(forKey: "native.recentSearches") ?? []
  }

  func rememberSearch(_ query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    var next = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
    next.insert(trimmed, at: 0)
    recentSearches = Array(next.prefix(10))
    userDefaults.set(recentSearches, forKey: "native.recentSearches")
  }

  func removeSearch(_ query: String) {
    recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
    userDefaults.set(recentSearches, forKey: "native.recentSearches")
  }

  func clearSearches() {
    recentSearches = []
    userDefaults.removeObject(forKey: "native.recentSearches")
  }
}
