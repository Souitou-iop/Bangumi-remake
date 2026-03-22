import Foundation
import SwiftUI

final class BangumiAppModel: ObservableObject {
  @Published var activeTab: BangumiTab = .home
  @Published var isShowingSearch = false
  @Published var isShowingLogin = false
  @Published var isShowingNotifications = false
  @Published var presentedRoute: BangumiModalRoute?
  @Published var presentedImage: BangumiImagePreview?

  let sessionStore: BangumiSessionStore
  let settingsStore: BangumiSettingsStore
  let apiClient: BangumiAPIClient
  let authService: BangumiAuthService
  let discoveryRepository: DiscoveryRepository
  let searchRepository: SearchRepository
  let timelineRepository: TimelineRepository
  let rakuenRepository: RakuenRepository
  let subjectRepository: SubjectRepository
  let userRepository: UserRepository
  let notificationStore: BangumiNotificationStore

  init() {
    sessionStore = BangumiSessionStore()
    settingsStore = BangumiSettingsStore()
    apiClient = BangumiAPIClient(sessionStore: sessionStore)
    authService = BangumiAuthService(apiClient: apiClient, sessionStore: sessionStore)
    discoveryRepository = DiscoveryRepository(apiClient: apiClient)
    searchRepository = SearchRepository(apiClient: apiClient)
    timelineRepository = TimelineRepository(apiClient: apiClient)
    rakuenRepository = RakuenRepository(apiClient: apiClient)
    subjectRepository = SubjectRepository(apiClient: apiClient)
    userRepository = UserRepository(apiClient: apiClient, sessionStore: sessionStore)
    notificationStore = BangumiNotificationStore(subjectRepository: subjectRepository)
  }

  var preferredColorScheme: ColorScheme? {
    settingsStore.preferredTheme.colorScheme
  }

  func present(url: URL) {
    guard let host = url.host?.lowercased() else {
      presentedRoute = .web(url, "网页")
      return
    }

    guard host.contains("bgm.tv") || host.contains("bangumi.tv") else {
      presentedRoute = .web(url, "网页")
      return
    }

    let path = url.path
    if let subjectID = Int(BangumiHTMLParser.firstCapture(in: path, pattern: #"^/subject/(\d+)"#) ?? "") {
      presentedRoute = .subject(subjectID)
      return
    }

    if let userID = BangumiHTMLParser.firstCapture(in: path, pattern: #"^/user/([^/]+)"#),
       !userID.isEmpty {
      presentedRoute = .user(userID)
      return
    }

    if path.contains("/timeline/status/") {
      presentedRoute = .timeline(url)
      return
    }

    if path.contains("/rakuen/topic/") || path.contains("/group/topic/") || path.contains("/subject/topic/") {
      presentedRoute = .rakuen(url)
      return
    }

    presentedRoute = .web(url, "网页")
  }

  func presentImage(_ url: URL) {
    presentedImage = BangumiImagePreview(url: url)
  }
}
