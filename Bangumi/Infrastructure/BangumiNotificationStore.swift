import BackgroundTasks
import Foundation
import SwiftUI
import UserNotifications

private extension UNUserNotificationCenter {
  func bangumiNotificationSettings() async -> UNNotificationSettings {
    await withCheckedContinuation { continuation in
      getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }
  }

  func bangumiRequestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      requestAuthorization(options: options) { granted, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: granted)
        }
      }
    }
  }
}

final class BangumiNotificationStore: NSObject, ObservableObject {
  static let backgroundRefreshIdentifier = "tv.bangumi.czy0729.subject-updates"
  static let subjectIDUserInfoKey = "subjectID"

  @Published private(set) var permissionState: BangumiNotificationPermissionState = .notDetermined
  @Published private(set) var subscriptions: [BangumiSubjectNotificationSubscription] = []
  @Published private(set) var isCheckingUpdates = false
  @Published private(set) var updatingSubjectIDs = Set<Int>()
  @Published private(set) var lastCheckedAt: Date?
  @Published var statusMessage: String?
  @Published var pendingOpenedSubjectID: Int?

  private let subjectRepository: SubjectRepository
  private let notificationCenter = UNUserNotificationCenter.current()
  private let userDefaults = UserDefaults.standard
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let automaticCheckInterval: TimeInterval = 15 * 60
  private let backgroundRefreshLeadTime: TimeInterval = 30 * 60
  private let subscriptionsKey = "native.notification.subscriptions"
  private let lastCheckedAtKey = "native.notification.lastCheckedAt"
  private var hasRegisteredBackgroundRefresh = false

  init(subjectRepository: SubjectRepository) {
    self.subjectRepository = subjectRepository
    super.init()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    decoder.dateDecodingStrategy = .millisecondsSince1970
    loadPersistedState()
    notificationCenter.delegate = self
    registerBackgroundRefreshIfNeeded()

    Task {
      await refreshPermissionState()
    }
  }

  func subscription(for subjectID: Int) -> BangumiSubjectNotificationSubscription? {
    subscriptions.first(where: { $0.subjectID == subjectID && $0.isEnabled })
  }

  func isSubscribed(subjectID: Int) -> Bool {
    subscription(for: subjectID) != nil
  }

  @MainActor
  func prepareForAppLaunch() async {
    await refreshPermissionState()
    await performAutomaticCheckIfNeeded(force: false)
  }

  @MainActor
  func handleScenePhase(_ phase: ScenePhase) async {
    switch phase {
    case .active:
      await refreshPermissionState()
      await performAutomaticCheckIfNeeded(force: false)
    case .background:
      scheduleBackgroundRefresh()
    case .inactive:
      break
    @unknown default:
      break
    }
  }

  @MainActor
  func refreshPermissionState() async {
    let settings = await notificationCenter.bangumiNotificationSettings()
    permissionState = Self.permissionState(from: settings.authorizationStatus)
  }

  @MainActor
  func toggleSubscription(subject: BangumiSubject, episodes: [BangumiEpisode]) async {
    if isSubscribed(subjectID: subject.id) {
      disableSubscription(subjectID: subject.id)
      return
    }

    updatingSubjectIDs.insert(subject.id)
    defer { updatingSubjectIDs.remove(subject.id) }

    if permissionState == .notDetermined {
      do {
        _ = try await notificationCenter.bangumiRequestAuthorization(options: [.alert, .badge, .sound])
      } catch {
        statusMessage = "通知权限请求失败：\(error.localizedDescription)"
      }
      await refreshPermissionState()
    }

    let latestEpisode = Self.latestEpisode(in: episodes)
    let now = Date()
    let subscription = BangumiSubjectNotificationSubscription(
      subjectID: subject.id,
      title: subject.nameCN ?? subject.name,
      subtitle: subject.nameCN == nil || subject.nameCN == subject.name ? nil : subject.name,
      coverURLString: subject.images?.best?.absoluteString,
      subjectTypeTitle: SubjectType.title(for: subject.type),
      latestEpisodeID: latestEpisode?.id,
      latestEpisodeSort: latestEpisode?.sort,
      latestEpisodeAirdate: latestEpisode?.airdate,
      latestEpisodeTitle: Self.episodeDisplayTitle(for: latestEpisode),
      lastKnownEpisodeCount: episodes.count,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
      lastCheckedAt: nil,
      lastNotifiedEpisodeID: nil,
      lastErrorMessage: nil
    )
    upsert(subscription)
    scheduleBackgroundRefresh()

    if permissionState.canDeliverNotifications {
      statusMessage = "已为《\(subscription.title)》开启更新提醒。"
    } else {
      statusMessage = "已记录《\(subscription.title)》的更新提醒，授权系统通知后会开始推送。"
    }
  }

  @MainActor
  func disableSubscription(subjectID: Int) {
    guard let target = subscription(for: subjectID) else { return }
    subscriptions.removeAll { $0.subjectID == subjectID }
    persistSubscriptions()
    scheduleBackgroundRefresh()
    statusMessage = "已关闭《\(target.title)》的更新提醒。"
  }

  @MainActor
  func disableAllSubscriptions() {
    guard !subscriptions.isEmpty else { return }
    subscriptions = []
    persistSubscriptions()
    cancelBackgroundRefresh()
    statusMessage = "已关闭全部条目提醒。"
  }

  @MainActor
  func performManualCheck() async {
    await runUpdateCheck(manual: true)
  }

  @MainActor
  func consumePendingOpenedSubjectID() {
    pendingOpenedSubjectID = nil
  }

  private func loadPersistedState() {
    if let data = userDefaults.data(forKey: subscriptionsKey),
       let decoded = try? decoder.decode([BangumiSubjectNotificationSubscription].self, from: data) {
      subscriptions = decoded.filter(\.isEnabled)
    }

    lastCheckedAt = userDefaults.object(forKey: lastCheckedAtKey) as? Date
  }

  @MainActor
  private func performAutomaticCheckIfNeeded(force: Bool) async {
    let hasActiveSubscriptions = subscriptions.contains(where: \.isEnabled)
    guard hasActiveSubscriptions else {
      cancelBackgroundRefresh()
      return
    }

    if !force,
       let lastCheckedAt,
       Date().timeIntervalSince(lastCheckedAt) < automaticCheckInterval {
      return
    }

    await runUpdateCheck(manual: false)
  }

  @MainActor
  private func runUpdateCheck(manual: Bool) async {
    let activeSubscriptions = subscriptions.filter(\.isEnabled)
    guard !activeSubscriptions.isEmpty else {
      if manual {
        statusMessage = "还没有订阅任何条目提醒。"
      }
      cancelBackgroundRefresh()
      return
    }

    isCheckingUpdates = true
    defer {
      isCheckingUpdates = false
      scheduleBackgroundRefresh()
    }

    let now = Date()
    var nextSubscriptions = subscriptions
    var updatesCount = 0
    var failedCount = 0

    for index in nextSubscriptions.indices {
      guard nextSubscriptions[index].isEnabled else { continue }

      var subscription = nextSubscriptions[index]
      do {
        let episodes = try await subjectRepository.fetchEpisodes(subjectID: subscription.subjectID)
        let latestEpisode = Self.latestEpisode(in: episodes)
        let checkResult = BangumiSubjectUpdateCheckResult(
          subjectID: subscription.subjectID,
          hasUpdate: Self.hasEpisodeUpdate(
            latestEpisode,
            comparedTo: subscription,
            episodeCount: episodes.count
          ),
          latestEpisode: latestEpisode,
          checkedAt: now,
          errorMessage: nil
        )

        subscription.latestEpisodeID = latestEpisode?.id
        subscription.latestEpisodeSort = latestEpisode?.sort
        subscription.latestEpisodeAirdate = latestEpisode?.airdate
        subscription.latestEpisodeTitle = Self.episodeDisplayTitle(for: latestEpisode)
        subscription.lastKnownEpisodeCount = episodes.count
        subscription.lastCheckedAt = checkResult.checkedAt
        subscription.updatedAt = checkResult.checkedAt
        subscription.lastErrorMessage = nil

        if checkResult.hasUpdate, let latestEpisode {
          updatesCount += 1
          if permissionState.canDeliverNotifications {
            await deliverNotification(for: subscription, latestEpisode: latestEpisode)
            subscription.lastNotifiedEpisodeID = latestEpisode.id
          }
        }
      } catch {
        failedCount += 1
        subscription.lastCheckedAt = now
        subscription.updatedAt = now
        subscription.lastErrorMessage = error.localizedDescription
      }

      nextSubscriptions[index] = subscription
    }

    subscriptions = nextSubscriptions.filter(\.isEnabled)
    lastCheckedAt = now
    persistSubscriptions()
    userDefaults.set(now, forKey: lastCheckedAtKey)

    if manual {
      if failedCount > 0, updatesCount == 0 {
        statusMessage = "检查完成，\(failedCount) 个条目读取失败。"
      } else if updatesCount > 0 {
        statusMessage = permissionState.canDeliverNotifications
          ? "检查完成，发现 \(updatesCount) 个条目有新章节。"
          : "检查完成，发现 \(updatesCount) 个条目有新章节，但系统通知尚未授权。"
      } else {
        statusMessage = "已经是最新进度，没有发现新章节。"
      }
    }
  }

  @MainActor
  private func deliverNotification(
    for subscription: BangumiSubjectNotificationSubscription,
    latestEpisode: BangumiEpisode
  ) async {
    let content = UNMutableNotificationContent()
    content.title = "《\(subscription.title)》有更新"
    content.body = "\(Self.episodeDisplayTitle(for: latestEpisode) ?? subscription.latestEpisodeLabel) 已加入条目时间线，点开继续查看详情。"
    content.sound = .default
    content.userInfo = [Self.subjectIDUserInfoKey: subscription.subjectID]

    let request = UNNotificationRequest(
      identifier: "subject-update-\(subscription.subjectID)-\(latestEpisode.id)",
      content: content,
      trigger: nil
    )

    do {
      try await notificationCenter.add(request)
    } catch {
      statusMessage = "系统通知发送失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  private func upsert(_ subscription: BangumiSubjectNotificationSubscription) {
    if let index = subscriptions.firstIndex(where: { $0.subjectID == subscription.subjectID }) {
      subscriptions[index] = subscription
    } else {
      subscriptions.insert(subscription, at: 0)
    }
    persistSubscriptions()
  }

  private func persistSubscriptions() {
    if let data = try? encoder.encode(subscriptions) {
      userDefaults.set(data, forKey: subscriptionsKey)
    }
  }

  private func registerBackgroundRefreshIfNeeded() {
    guard !hasRegisteredBackgroundRefresh else { return }
    hasRegisteredBackgroundRefresh = true

    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundRefreshIdentifier, using: nil) { [weak self] task in
      guard let self, let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }

      self.handleBackgroundRefresh(task: refreshTask)
    }
  }

  private func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh()
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    Task { @MainActor [weak self] in
      guard let self else {
        task.setTaskCompleted(success: false)
        return
      }

      await self.refreshPermissionState()
      await self.runUpdateCheck(manual: false)
      task.setTaskCompleted(success: true)
    }
  }

  private func scheduleBackgroundRefresh() {
    let activeSubscriptions = subscriptions.contains(where: \.isEnabled)
    guard activeSubscriptions else {
      cancelBackgroundRefresh()
      return
    }

    let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: backgroundRefreshLeadTime)
    try? BGTaskScheduler.shared.submit(request)
  }

  private func cancelBackgroundRefresh() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshIdentifier)
  }

  private static func permissionState(from status: UNAuthorizationStatus) -> BangumiNotificationPermissionState {
    switch status {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    case .provisional: .provisional
    case .ephemeral: .ephemeral
    @unknown default: .notDetermined
    }
  }

  private static func latestEpisode(in episodes: [BangumiEpisode]) -> BangumiEpisode? {
    episodes.max { lhs, rhs in
      let lhsSort = lhs.sort ?? -Double.greatestFiniteMagnitude
      let rhsSort = rhs.sort ?? -Double.greatestFiniteMagnitude
      if lhsSort == rhsSort {
        return lhs.id < rhs.id
      }
      return lhsSort < rhsSort
    }
  }

  private static func episodeDisplayTitle(for episode: BangumiEpisode?) -> String? {
    guard let episode else { return nil }

    let prefix: String
    if let sort = episode.sort {
      if sort.rounded(.towardZero) == sort {
        prefix = "第 \(Int(sort)) 集"
      } else {
        prefix = "第 \(sort.formatted(.number.precision(.fractionLength(1)))) 集"
      }
    } else {
      prefix = "章节"
    }

    let title = episode.nameCN ?? episode.name
    guard let title, !title.isEmpty else { return prefix }
    return "\(prefix) · \(title)"
  }

  private static func hasEpisodeUpdate(
    _ latestEpisode: BangumiEpisode?,
    comparedTo subscription: BangumiSubjectNotificationSubscription,
    episodeCount: Int
  ) -> Bool {
    guard let latestEpisode else {
      return false
    }

    if let previousEpisodeID = subscription.latestEpisodeID,
       previousEpisodeID == latestEpisode.id {
      return false
    }

    if let previousSort = subscription.latestEpisodeSort,
       let latestSort = latestEpisode.sort {
      if latestSort > previousSort {
        return true
      }
      if latestSort < previousSort {
        return false
      }
    }

    if let previousEpisodeID = subscription.latestEpisodeID {
      return latestEpisode.id > previousEpisodeID
    }

    return subscription.lastKnownEpisodeCount == 0 && episodeCount > 0
  }
}

extension BangumiNotificationStore: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let subjectID = (userInfo[Self.subjectIDUserInfoKey] as? Int) ??
      (userInfo[Self.subjectIDUserInfoKey] as? String).flatMap(Int.init)

    if let subjectID {
      Task { @MainActor [weak self] in
        self?.pendingOpenedSubjectID = subjectID
      }
    }

    completionHandler()
  }
}
