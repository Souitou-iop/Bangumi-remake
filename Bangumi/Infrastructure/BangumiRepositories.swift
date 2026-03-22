import Foundation

final class BangumiAuthService {
  private let apiClient: BangumiAPIClient
  private let sessionStore: BangumiSessionStore

  init(apiClient: BangumiAPIClient, sessionStore: BangumiSessionStore) {
    self.apiClient = apiClient
    self.sessionStore = sessionStore
  }

  func signInWithAuthorizationCode(_ code: String) async throws {
    let token = try await apiClient.exchangeCodeForToken(code: code)
    let user = try await apiClient.fetchCurrentUser(using: token)
    await MainActor.run {
      sessionStore.update(token: token, user: user)
    }
  }

  func signInWithToken(_ rawToken: String) async throws {
    let token = BangumiToken(
      accessToken: rawToken,
      tokenType: "Bearer",
      expiresIn: 604_800,
      refreshToken: nil,
      userID: nil
    )
    let user = try await apiClient.fetchCurrentUser(using: token)
    await MainActor.run {
      sessionStore.update(token: token, user: user)
    }
  }
}

final class DiscoveryRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetchCalendar() async throws -> [BangumiCalendarDay] {
    try await apiClient.fetchCalendar()
  }
}

final class SearchRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func search(query: BangumiSearchQuery) async throws -> [BangumiSubjectSummary] {
    switch query.matchMode {
    case .precise:
      try await apiClient.searchSubjects(keyword: query.keyword, type: query.type)
    case .fuzzy:
      try await apiClient.searchSubjectsFromWeb(keyword: query.keyword, type: query.type)
    }
  }
}

final class TimelineRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetch(page: Int, filter: TimelineFilter) async throws -> BangumiTimelinePage {
    try await apiClient.fetchTimeline(page: page, filter: filter)
  }

  func fetchDetail(url: URL) async throws -> BangumiTimelineDetail {
    try await apiClient.fetchTimelineDetail(url: url)
  }
}

final class RakuenRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetch(filter: RakuenFilter) async throws -> [BangumiRakuenItem] {
    try await apiClient.fetchRakuen(filter: filter)
  }

  func fetchTopic(url: URL) async throws -> BangumiRakuenTopicDetail {
    try await apiClient.fetchRakuenTopic(url: url)
  }
}

final class SubjectRepository {
  private let apiClient: BangumiAPIClient

  init(apiClient: BangumiAPIClient) {
    self.apiClient = apiClient
  }

  func fetchSubject(id: Int) async throws -> BangumiSubject {
    try await apiClient.fetchSubject(id: id)
  }

  func fetchEpisodes(subjectID: Int) async throws -> [BangumiEpisode] {
    try await apiClient.fetchEpisodes(subjectID: subjectID)
  }

  func fetchCollection(subjectID: Int) async throws -> BangumiSubjectCollectionRecord {
    try await apiClient.fetchCollection(subjectID: subjectID)
  }

  func fetchEpisodeCollections(subjectID: Int) async throws -> [BangumiEpisodeCollection] {
    try await apiClient.fetchEpisodeCollections(subjectID: subjectID)
  }

  func fetchSubjectComments(subjectID: Int) async throws -> [BangumiSubjectComment] {
    try await apiClient.fetchSubjectComments(subjectID: subjectID)
  }

  func fetchSubjectPresentation(subjectID: Int) async throws -> BangumiSubjectPresentation {
    try await apiClient.fetchSubjectPresentation(subjectID: subjectID)
  }

  func updateCollection(subjectID: Int, payload: CollectionUpdatePayload) async throws {
    try await apiClient.updateCollection(subjectID: subjectID, payload: payload)
  }

  func updateEpisodeCollection(episodeID: Int, type: BangumiEpisodeCollectionType) async throws {
    try await apiClient.updateEpisodeCollection(episodeID: episodeID, type: type)
  }

  func markEpisodeWatched(episodeID: Int) async throws {
    try await apiClient.markEpisodeWatched(episodeID: episodeID)
  }

  func updateWatchedProgress(
    subjectID: Int,
    watchedEpisodes: Int? = nil,
    watchedVolumes: Int? = nil
  ) async throws {
    try await apiClient.updateWatchedProgress(
      subjectID: subjectID,
      watchedEpisodes: watchedEpisodes,
      watchedVolumes: watchedVolumes
    )
  }
}

final class UserRepository {
  private let apiClient: BangumiAPIClient
  private let sessionStore: BangumiSessionStore

  init(apiClient: BangumiAPIClient, sessionStore: BangumiSessionStore) {
    self.apiClient = apiClient
    self.sessionStore = sessionStore
  }

  func refreshCurrentUser() async throws -> BangumiUser {
    let user = try await apiClient.fetchCurrentUser()
    if let token = sessionStore.token {
      await MainActor.run {
        sessionStore.update(token: token, user: user)
      }
    }
    return user
  }

  func fetchWatchingCollections(subjectType: SubjectType = .anime, limit: Int = 20) async throws -> [BangumiCollectionItem] {
    guard let currentUser = sessionStore.currentUser else {
      throw BangumiError.missingCurrentUser
    }

    let identifier = currentUser.username.isEmpty ? String(currentUser.id) : currentUser.username
    return try await apiClient.fetchWatchingCollections(userID: identifier, subjectType: subjectType, limit: limit)
  }

  func fetchCollections(
    status: CollectionStatus,
    subjectType: SubjectType = .anime,
    limit: Int = 20,
    offset: Int = 0
  ) async throws -> BangumiCollectionPage {
    guard let currentUser = sessionStore.currentUser else {
      throw BangumiError.missingCurrentUser
    }

    let identifier = currentUser.username.isEmpty ? String(currentUser.id) : currentUser.username
    return try await apiClient.fetchCollections(
      userID: identifier,
      subjectType: subjectType,
      status: status,
      limit: limit,
      offset: offset
    )
  }

  func fetchUserProfile(userID: String) async throws -> BangumiUserProfile {
    try await apiClient.fetchUserProfile(userID: userID)
  }

  func fetchWatchingCollections(
    userID: String,
    subjectType: SubjectType = .anime,
    limit: Int = 20
  ) async throws -> [BangumiCollectionItem] {
    try await apiClient.fetchWatchingCollections(userID: userID, subjectType: subjectType, limit: limit)
  }

  func fetchCollections(
    userID: String,
    status: CollectionStatus,
    subjectType: SubjectType = .anime,
    limit: Int = 20,
    offset: Int = 0
  ) async throws -> BangumiCollectionPage {
    try await apiClient.fetchCollections(
      userID: userID,
      subjectType: subjectType,
      status: status,
      limit: limit,
      offset: offset
    )
  }
}
