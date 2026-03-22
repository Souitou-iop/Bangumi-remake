import Foundation

@MainActor
final class MeViewModel: ObservableObject {
  @Published var currentUser: BangumiUser?
  @Published var selectedStatus: CollectionStatus = .doing
  @Published var sortOrder: MeCollectionSortOrder = .updatedAt
  @Published var selectedTag: MeCollectionTag = .all
  @Published var searchText = ""
  @Published var isRefreshing = false
  @Published var errorMessage: String?
  @Published private(set) var buckets: [CollectionStatus: MeCollectionBucket] = [:]
  @Published private(set) var statusCounts: [CollectionStatus: Int] = [:]

  private let pageSize = 24
  private var bootstrappedUserID: Int?

  var summaries: [MeStatusSummary] {
    CollectionStatus.allCases.map { status in
      MeStatusSummary(status: status, count: statusCounts[status] ?? 0)
    }
  }

  var selectedItems: [BangumiCollectionItem] {
    let items = buckets[selectedStatus]?.items ?? []

    return items
      .filter(matchesSearch)
      .filter(matchesTag)
      .sorted(by: sortComparator)
  }

  var availableTags: [MeCollectionTag] {
    let tags = Set((buckets[selectedStatus]?.items ?? []).map(\.meYearTag))
    let sorted = tags.sorted { lhs, rhs in
      switch (lhs, rhs) {
      case (.year(let left), .year(let right)):
        return left > right
      case (.year, .undated):
        return true
      case (.undated, .year):
        return false
      default:
        return false
      }
    }

    return [.all] + sorted
  }

  var isLoadingSelectedStatus: Bool {
    buckets[selectedStatus]?.isLoading ?? false
  }

  var canLoadMoreSelectedStatus: Bool {
    buckets[selectedStatus]?.canLoadMore ?? false
  }

  func bootstrap(using repository: UserRepository, sessionStore: BangumiSessionStore) async {
    guard sessionStore.isAuthenticated, let user = sessionStore.currentUser else {
      reset()
      return
    }

    if bootstrappedUserID != user.id {
      resetCollections()
      bootstrappedUserID = user.id
    }

    currentUser = user
    await refresh(using: repository, sessionStore: sessionStore)
  }

  func refresh(using repository: UserRepository, sessionStore: BangumiSessionStore) async {
    guard sessionStore.isAuthenticated else {
      reset()
      return
    }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let refreshedUser = try await repository.refreshCurrentUser()
      currentUser = refreshedUser
      try await loadStatusCounts(using: repository)
      try await loadCollections(for: selectedStatus, using: repository, reset: true)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func selectStatus(_ status: CollectionStatus, using repository: UserRepository) async {
    guard status != selectedStatus else { return }
    selectedStatus = status
    selectedTag = .all
    searchText = ""

    let bucket = buckets[status] ?? MeCollectionBucket()
    if !bucket.hasLoaded {
      do {
        try await loadCollections(for: status, using: repository, reset: true)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func loadMore(using repository: UserRepository) async {
    do {
      try await loadCollections(for: selectedStatus, using: repository, reset: false)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadStatusCounts(using repository: UserRepository) async throws {
    var nextCounts: [CollectionStatus: Int] = [:]

    try await withThrowingTaskGroup(of: (CollectionStatus, Int).self) { group in
      for status in CollectionStatus.allCases {
        group.addTask {
          let page = try await repository.fetchCollections(
            status: status,
            subjectType: .anime,
            limit: 1,
            offset: 0
          )
          return (status, page.total)
        }
      }

      for try await (status, total) in group {
        nextCounts[status] = total
      }
    }

    statusCounts = nextCounts
  }

  private func loadCollections(
    for status: CollectionStatus,
    using repository: UserRepository,
    reset: Bool
  ) async throws {
    var bucket = buckets[status] ?? MeCollectionBucket()
    guard !bucket.isLoading else { return }

    bucket.isLoading = true
    buckets[status] = bucket

    let offset = reset ? 0 : bucket.nextOffset

    do {
      let page = try await repository.fetchCollections(
        status: status,
        subjectType: .anime,
        limit: pageSize,
        offset: offset
      )

      var nextBucket = buckets[status] ?? MeCollectionBucket()
      nextBucket.total = page.total
      nextBucket.hasLoaded = true
      nextBucket.isLoading = false
      nextBucket.items = reset ? page.items : merge(existing: nextBucket.items, with: page.items)
      nextBucket.nextOffset = nextBucket.items.count
      nextBucket.canLoadMore = nextBucket.items.count < page.total
      buckets[status] = nextBucket
      statusCounts[status] = page.total
    } catch {
      bucket.isLoading = false
      buckets[status] = bucket
      throw error
    }
  }

  private func merge(existing: [BangumiCollectionItem], with next: [BangumiCollectionItem]) -> [BangumiCollectionItem] {
    var merged = existing
    let existingIDs = Set(existing.map(\.id))
    merged.append(contentsOf: next.filter { !existingIDs.contains($0.id) })
    return merged
  }

  private func matchesSearch(_ item: BangumiCollectionItem) -> Bool {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }

    let keyword = trimmed.lowercased()
    return item.meDisplayTitle.lowercased().contains(keyword)
      || (item.meSecondaryTitle?.lowercased().contains(keyword) ?? false)
  }

  private func matchesTag(_ item: BangumiCollectionItem) -> Bool {
    switch selectedTag {
    case .all:
      true
    case let .year(value):
      item.meYearTag == .year(value)
    case .undated:
      item.meYearTag == .undated
    }
  }

  private func sortComparator(lhs: BangumiCollectionItem, rhs: BangumiCollectionItem) -> Bool {
    switch sortOrder {
    case .updatedAt:
      return (lhs.updatedAt ?? "") > (rhs.updatedAt ?? "")
    case .title:
      return lhs.meDisplayTitle.localizedCompare(rhs.meDisplayTitle) == .orderedAscending
    case .score:
      return (lhs.subject.score ?? 0) > (rhs.subject.score ?? 0)
    case .airDate:
      return (lhs.subject.date ?? "") > (rhs.subject.date ?? "")
    }
  }

  private func resetCollections() {
    buckets = Dictionary(uniqueKeysWithValues: CollectionStatus.allCases.map { ($0, MeCollectionBucket()) })
    statusCounts = [:]
    selectedStatus = .doing
    selectedTag = .all
    searchText = ""
  }

  private func reset() {
    currentUser = nil
    bootstrappedUserID = nil
    errorMessage = nil
    isRefreshing = false
    resetCollections()
  }
}
