import Foundation

@main
struct OAuthStateRegression {
  static func main() async throws {
    let sessionStore = BangumiSessionStore()
    let client = BangumiAPIClient(sessionStore: sessionStore)

    let authorization = client.beginOAuthAuthorization()
    let authorizeComponents = URLComponents(url: authorization.authorizeURL, resolvingAgainstBaseURL: false)
    let queryItems = authorizeComponents?.queryItems ?? []

    expect(queryItems.contains(where: { $0.name == "client_id" && $0.value == client.config.appID }), "authorize URL should include client_id")
    expect(queryItems.contains(where: { $0.name == "redirect_uri" && $0.value == client.config.callbackURL.absoluteString }), "authorize URL should include redirect_uri")
    expect(queryItems.contains(where: { $0.name == "state" && $0.value == authorization.state }), "authorize URL should include state")

    let successURL = try unwrap(
      URL(string: "\(client.config.callbackURL.absoluteString)?code=abc123&state=\(authorization.state)"),
      "success callback URL"
    )
    let code = try client.consumeOAuthCallback(successURL)
    expect(code == "abc123", "consumeOAuthCallback should return code on matching state")

    _ = client.beginOAuthAuthorization()
    let missingStateURL = try unwrap(
      URL(string: "\(client.config.callbackURL.absoluteString)?code=missing-state"),
      "missing-state callback URL"
    )
    expectThrows(BangumiError.oauthStateMissing, message: "missing state should throw oauthStateMissing") {
      _ = try client.consumeOAuthCallback(missingStateURL)
    }

    let mismatchAuthorization = client.beginOAuthAuthorization()
    let mismatchURL = try unwrap(
      URL(string: "\(client.config.callbackURL.absoluteString)?code=mismatch&state=wrong-\(mismatchAuthorization.state)"),
      "mismatch callback URL"
    )
    expectThrows(BangumiError.oauthStateMismatch, message: "wrong state should throw oauthStateMismatch") {
      _ = try client.consumeOAuthCallback(mismatchURL)
    }

    _ = client.beginOAuthAuthorization()
    client.cancelOAuthAuthorization()
    let cancelledURL = try unwrap(
      URL(string: "\(client.config.callbackURL.absoluteString)?code=after-cancel&state=unused"),
      "cancelled callback URL"
    )
    expectThrows(BangumiError.oauthStateMismatch, message: "cancelled authorization should reject stale callback") {
      _ = try client.consumeOAuthCallback(cancelledURL)
    }
  }

  static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
      fputs("Assertion failed: \(message)\n", stderr)
      exit(1)
    }
  }

  static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
      throw NSError(domain: "OAuthStateRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create \(message)"])
    }
    return value
  }

  static func expectThrows(
    _ expected: BangumiError,
    message: String,
    _ operation: () throws -> Void
  ) {
    do {
      try operation()
      fputs("Assertion failed: \(message)\n", stderr)
      exit(1)
    } catch let error as BangumiError {
      guard error == expected else {
        fputs("Assertion failed: expected \(expected), got \(error)\n", stderr)
        exit(1)
      }
    } catch {
      fputs("Assertion failed: expected BangumiError \(expected), got \(error)\n", stderr)
      exit(1)
    }
  }
}
