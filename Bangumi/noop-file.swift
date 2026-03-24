import BackgroundTasks
import Foundation
import Security
import SwiftUI
import UIKit
import UserNotifications
import WebKit

@objc(BangumiRootViewFactory)
public final class BangumiRootViewFactory: NSObject {
  private static let model = BangumiAppModel()

  @objc public static func makeRootViewController() -> UIViewController {
    let controller = UIHostingController(
      rootView: BangumiRootView()
        .environmentObject(model)
        .environmentObject(model.sessionStore)
        .environmentObject(model.settingsStore)
        .environmentObject(model.notificationStore)
    )
    controller.view.backgroundColor = .systemGroupedBackground
    return controller
  }
}

private struct BangumiRootView: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()

      TabView(selection: $model.activeTab) {
        Tab("首页", systemImage: "rectangle.grid.2x2.fill", value: .home) {
          NavigationStack {
            HomeScreen()
          }
        }

        Tab("发现", systemImage: "sparkles", value: .discovery) {
          NavigationStack {
            DiscoveryScreen()
          }
        }

        Tab("我的", systemImage: "person.circle", value: .me) {
          NavigationStack {
            MeScreen()
          }
        }

        Tab(value: .search, role: .search) {
          NavigationStack {
            SearchScreen()
          }
        }
      }
      .tabBarMinimizeBehavior(.onScrollDown)
      .tabViewSearchActivation(.searchTabSelection)
      .searchable(
        text: $model.searchDraft,
        isPresented: $model.isShowingSearch,
        prompt: "动画、书籍、游戏以及更多..."
      )
      .searchSuggestions {
        ForEach(settingsStore.recentSearches.prefix(5), id: \.self) { item in
          Button(item) {
            model.searchDraft = item
            model.requestSearchSubmission()
          }
          .searchCompletion(item)
        }
      }
      .onSubmit(of: .search) {
        model.requestSearchSubmission()
      }
    }
    .preferredColorScheme(settingsStore.preferredTheme.colorScheme)
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .tabBar)
    .sheet(isPresented: $model.isShowingLogin) {
      NavigationStack {
        LoginScreen()
      }
      .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingNotifications) {
      NavigationStack {
        NotificationManagementScreen(showsDismissButton: true)
      }
    }
    .sheet(item: $model.presentedRoute) { route in
      NavigationStack {
        switch route {
        case let .subject(subjectID):
          SubjectDetailScreen(subjectID: subjectID)
        case let .user(userID):
          UserProfileScreen(userID: userID)
        case let .timeline(url):
          TimelineDetailScreen(url: url, fallbackTitle: "时间线详情")
        case let .rakuen(url):
          RakuenTopicScreen(topicURL: url, fallbackTitle: "Rakuen")
        case let .web(url, title):
          WebFallbackScreen(title: title, subtitle: nil, url: url)
        }
      }
      .environmentObject(model)
    }
    .fullScreenCover(item: $model.presentedImage) { item in
      BangumiImagePreviewScreen(imageURL: item.url)
    }
    .task {
      await notificationStore.prepareForAppLaunch()
    }
    .onChange(of: scenePhase) { _, newValue in
      Task {
        await notificationStore.handleScenePhase(newValue)
      }
    }
    .onChange(of: notificationStore.pendingOpenedSubjectID) { _, subjectID in
      guard let subjectID else { return }
      model.presentedRoute = .subject(subjectID)
      notificationStore.consumePendingOpenedSubjectID()
    }
    .onChange(of: model.activeTab) { _, newValue in
      model.isShowingSearch = newValue == .search
      if newValue != .search {
        model.searchShouldAutoSubmit = false
      }
    }
  }
}

private struct BangumiCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(BangumiDesign.cardPadding)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: BangumiDesign.cardRadius))
  }
}

private extension View {
  func bangumiCardStyle() -> some View {
    modifier(BangumiCardModifier())
  }

  func bangumiRootScrollableLayout() -> some View {
    listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color(uiColor: .systemGroupedBackground))
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Color.clear
          .frame(height: BangumiDesign.rootTabBarClearance)
      }
  }
}

private struct BangumiRichText: View {
  let html: String
  private let baseURL = URL(string: "https://bgm.tv")!
  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    let quotes = BangumiHTMLParser.quoteBlocks(in: html)
    let imageURLs = Array(BangumiHTMLParser.imageURLs(in: html, baseURL: baseURL).prefix(4))

    VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
      if let attributed = BangumiHTMLParser.attributedString(from: html, baseURL: baseURL),
         !attributed.characters.isEmpty {
        Text(attributed)
          .tint(.accentColor)
      } else {
        Text(BangumiHTMLParser.stripTags(html))
      }

      if !quotes.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(quotes, id: \.self) { quote in
            HStack(alignment: .top, spacing: BangumiDesign.sectionSpacing) {
              RoundedRectangle(cornerRadius: 999)
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 4)

              Text(quote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(BangumiDesign.cardPadding)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
          }
        }
      }

      if !imageURLs.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(imageURLs, id: \.absoluteString) { imageURL in
            Button {
              model.presentImage(imageURL)
            } label: {
              AsyncImage(url: imageURL) { image in
                image
                  .resizable()
                  .scaledToFill()
              } placeholder: {
                RoundedRectangle(cornerRadius: 14)
                  .fill(Color.secondary.opacity(0.12))
                  .overlay {
                    ProgressView()
                  }
              }
              .frame(maxWidth: .infinity)
              .frame(height: 180)
              .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看图片")
          }
        }
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      model.present(url: url)
      return .handled
    })
  }
}

private struct BangumiImagePreviewScreen: View {
  let imageURL: URL

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()

      AsyncImage(url: imageURL) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
      } placeholder: {
        ProgressView()
          .tint(.white)
      }

      Button("关闭", systemImage: "xmark.circle.fill") {
        dismiss()
      }
      .labelStyle(.iconOnly)
      .font(.title2)
      .padding()
      .tint(.white)
    }
  }
}

private struct UserNameButton: View {
  let title: String
  let userID: String?
  var font: Font = .headline

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    Group {
      if let userID, !userID.isEmpty {
        Button(title) {
          model.present(url: URL(string: "https://bgm.tv/user/\(userID)")!)
        }
        .buttonStyle(.plain)
      } else {
        Text(title)
      }
    }
    .font(font)
    .foregroundStyle(.primary)
  }
}

private enum BangumiNavigationBarStyle {
  case solid
  case discoveryNative
  case hidden
}

private struct ScreenScaffold<Content: View>: View {
  let title: String
  let subtitle: String?
  let navigationBarStyle: BangumiNavigationBarStyle
  let showsNavigationTitle: Bool
  let content: Content

  @EnvironmentObject private var model: BangumiAppModel

  init(
    title: String,
    subtitle: String? = nil,
    navigationBarStyle: BangumiNavigationBarStyle = .solid,
    showsNavigationTitle: Bool = true,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.navigationBarStyle = navigationBarStyle
    self.showsNavigationTitle = showsNavigationTitle
    self.content = content()
  }

  var body: some View {
    let scaffold = ZStack {
      Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()

      content
    }

    switch navigationBarStyle {
    case .solid:
      if showsNavigationTitle {
        scaffold
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
      } else {
        scaffold
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
      }
    case .discoveryNative:
      if showsNavigationTitle {
        scaffold
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.hidden, for: .navigationBar)
      } else {
        scaffold
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
              Button("通知", systemImage: "bell.badge") {
                model.isShowingNotifications = true
              }
              .labelStyle(.iconOnly)
            }
          }
          .toolbarBackground(.hidden, for: .navigationBar)
      }
    case .hidden:
      scaffold
        .toolbar(.hidden, for: .navigationBar)
    }
  }
}

private struct UserProfileScreen: View {
  let userID: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = UserProfileViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.profile == nil {
        ProgressView("加载中...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage, viewModel.profile == nil {
        UnavailableStateView(
          title: userID,
          systemImage: "person.crop.circle.badge.exclamationmark",
          message: error
        )
      } else {
        List {
          if let profile = viewModel.profile {
            Section {
              VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                  CoverImage(url: profile.avatarURL)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: BangumiDesign.heroRadius, style: .continuous))
                    .accessibilityHidden(true)

                  VStack(alignment: .leading, spacing: 6) {
                    Text(profile.displayName)
                      .font(.title3.weight(.semibold))

                    Text("@\(profile.username)")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)

                    if let sign = profile.sign, !sign.isEmpty {
                      Text(sign)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                  }
                }

                if let bio = profile.bio, !bio.isEmpty {
                  Text(bio)
                    .font(.body)
                }

                HStack(spacing: 16) {
                  if let location = profile.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                  }
                  if let joinedAt = profile.joinedAt, !joinedAt.isEmpty {
                    Label(joinedAt, systemImage: "calendar")
                  }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .bangumiCardStyle()
              .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
              .listRowBackground(Color.clear)
            }

            if !viewModel.collections.isEmpty {
              Section("在看动画") {
                ForEach(viewModel.collections) { item in
                  NavigationLink {
                    SubjectDetailScreen(subjectID: item.subjectID)
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(item.subject.nameCN ?? item.subject.name)
                      if let epStatus = item.epStatus {
                        Text("已追到第 \(epStatus) 集")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                    }
                  }
                }
              }
            } else if viewModel.profile != nil {
              Section("在看动画") {
                Text("当前没有读取到公开的在看动画，稍后可以通过 Safari 查看原站页面。")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .refreshable {
          await viewModel.refresh(using: model.userRepository, userID: userID)
        }
      }
    }
    .navigationTitle(viewModel.profile?.displayName ?? userID)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Link(destination: URL(string: "https://bgm.tv/user/\(userID)")!) {
          Label("在 Safari 中打开", systemImage: "safari")
            .labelStyle(.iconOnly)
        }
      }
    }
    .task {
      await viewModel.load(using: model.userRepository, userID: userID)
    }
  }
}

private final class UserProfileViewModel: ObservableObject {
  @Published var profile: BangumiUserProfile?
  @Published var collections: [BangumiCollectionItem] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var loadedUserID: String?

  @MainActor
  func load(using repository: UserRepository, userID: String) async {
    if loadedUserID == userID, profile != nil { return }
    await refresh(using: repository, userID: userID)
  }

  @MainActor
  func refresh(using repository: UserRepository, userID: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let profileTask = repository.fetchUserProfile(userID: userID)
      async let collectionsTask = repository.fetchWatchingCollections(userID: userID)
      profile = try await profileTask
      collections = (try? await collectionsTask) ?? []
      loadedUserID = userID
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct HomeCollectionsSection: Identifiable {
  let category: HomeCategory
  let items: [BangumiCollectionItem]

  var id: String { category.rawValue }
}

private struct HomeScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @StateObject private var viewModel = HomeViewModel()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color.accentColor.opacity(0.12),
          Color(uiColor: .systemGroupedBackground),
          Color(uiColor: .secondarySystemGroupedBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HomeHeader(
            isAuthenticated: sessionStore.isAuthenticated,
            currentUser: sessionStore.currentUser,
            onProfile: {
              model.activeTab = .me
            },
            onLogin: {
              model.isShowingLogin = true
            }
          )

          HomeCategoryBar(selection: $viewModel.selectedCategory)

          if let error = viewModel.errorMessage {
            SubjectInlineMessageCard(message: error)
          }

          if sessionStore.isAuthenticated {
            authenticatedContent
          } else {
            guestContent
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
      }
      .refreshable {
        await viewModel.refresh(
          using: model.userRepository,
          discoveryRepository: model.discoveryRepository,
          isAuthenticated: sessionStore.isAuthenticated
        )
      }
    }
    .task(id: sessionStore.isAuthenticated) {
      await viewModel.load(
        using: model.userRepository,
        discoveryRepository: model.discoveryRepository,
        isAuthenticated: sessionStore.isAuthenticated
      )
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button("通知", systemImage: "bell.badge") {
          model.isShowingNotifications = true
        }
        .labelStyle(.iconOnly)
      }
    }
    .toolbarBackground(.hidden, for: .navigationBar)
  }

  @ViewBuilder
  private var authenticatedContent: some View {
    if viewModel.isLoading && viewModel.totalCollectionCount == 0 {
      ProgressView("正在加载首页...")
        .frame(maxWidth: .infinity, minHeight: 280)
    } else if viewModel.totalCollectionCount == 0 {
      UnavailableStateView(
        title: "首页",
        systemImage: "square.stack.3d.up.slash",
        message: "暂时没有读取到在看中的收藏，可以稍后刷新，或先去发现页逛逛。"
      )
    } else {
      if viewModel.selectedCategory == .all {
        ForEach(viewModel.sectionsForAll) { section in
          HomeCollectionSectionView(
            title: section.category.title,
            subtitle: section.category == .anime ? "继续追番" : "最近更新",
            items: section.items
          )
        }
      } else {
        let items = viewModel.collections(for: viewModel.selectedCategory)
        if items.isEmpty {
          UnavailableStateView(
            title: viewModel.selectedCategory.title,
            systemImage: "tray",
            message: "当前分类下没有在看中的条目。"
          )
        } else {
          HomeCollectionSectionView(
            title: viewModel.selectedCategory.title,
            subtitle: "根据你的收藏进度整理",
            items: items
          )
        }
      }
    }
  }

  @ViewBuilder
  private var guestContent: some View {
    HomeGuestHeroCard {
      model.isShowingLogin = true
    }

    if viewModel.isLoading && viewModel.guestDays.isEmpty {
      ProgressView("正在加载首页...")
        .frame(maxWidth: .infinity, minHeight: 220)
    } else if viewModel.selectedCategory == .book || viewModel.selectedCategory == .real || viewModel.selectedCategory == .game {
      UnavailableStateView(
        title: viewModel.selectedCategory.title,
        systemImage: "person.crop.circle.badge.plus",
        message: "登录后可查看你的\(viewModel.selectedCategory.title)进度。"
      )
    } else if viewModel.guestDays.isEmpty {
      UnavailableStateView(
        title: "首页",
        systemImage: "sparkles",
        message: "暂时没有读取到推荐内容，可以稍后刷新。"
      )
    } else {
      ForEach(viewModel.displayedGuestDays) { day in
        HomeGuestSectionView(day: day)
      }
    }
  }
}

private final class HomeViewModel: ObservableObject {
  @Published var selectedCategory: HomeCategory = .all
  @Published var animeCollections: [BangumiCollectionItem] = []
  @Published var bookCollections: [BangumiCollectionItem] = []
  @Published var realCollections: [BangumiCollectionItem] = []
  @Published var gameCollections: [BangumiCollectionItem] = []
  @Published var guestDays: [BangumiCalendarDay] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var hasLoadedForAuthState: Bool?

  var totalCollectionCount: Int {
    collections(for: .all).count
  }

  var sectionsForAll: [HomeCollectionsSection] {
    [
      HomeCollectionsSection(category: .anime, items: animeCollections),
      HomeCollectionsSection(category: .book, items: bookCollections),
      HomeCollectionsSection(category: .real, items: realCollections),
      HomeCollectionsSection(category: .game, items: gameCollections)
    ]
    .filter { !$0.items.isEmpty }
  }

  var displayedGuestDays: [BangumiCalendarDay] {
    Array(guestDays.prefix(3))
  }

  func collections(for category: HomeCategory) -> [BangumiCollectionItem] {
    switch category {
    case .anime:
      animeCollections
    case .book:
      bookCollections
    case .real:
      realCollections
    case .game:
      gameCollections
    case .all:
      sortCollections(animeCollections + bookCollections + realCollections + gameCollections)
    }
  }

  @MainActor
  func load(
    using repository: UserRepository,
    discoveryRepository: DiscoveryRepository,
    isAuthenticated: Bool
  ) async {
    if hasLoadedForAuthState == isAuthenticated {
      let hasData = isAuthenticated ? totalCollectionCount > 0 : !guestDays.isEmpty
      if hasData { return }
    }
    await refresh(using: repository, discoveryRepository: discoveryRepository, isAuthenticated: isAuthenticated)
  }

  @MainActor
  func refresh(
    using repository: UserRepository,
    discoveryRepository: DiscoveryRepository,
    isAuthenticated: Bool
  ) async {
    isLoading = true
    defer { isLoading = false }

    if isAuthenticated {
      do {
        async let anime = repository.fetchWatchingCollections(subjectType: .anime, limit: 24)
        async let book = repository.fetchWatchingCollections(subjectType: .book, limit: 24)
        async let real = repository.fetchWatchingCollections(subjectType: .real, limit: 24)
        async let game = repository.fetchWatchingCollections(subjectType: .game, limit: 24)

        animeCollections = sortCollections((try? await anime) ?? [])
        bookCollections = sortCollections((try? await book) ?? [])
        realCollections = sortCollections((try? await real) ?? [])
        gameCollections = sortCollections((try? await game) ?? [])
        guestDays = []
        errorMessage = totalCollectionCount == 0 ? "已切换到首页，但当前没有读取到可展示的在看条目。" : nil
      }
      guestDays = []
    } else {
      do {
        guestDays = try await discoveryRepository.fetchCalendar()
        animeCollections = []
        bookCollections = []
        realCollections = []
        gameCollections = []
        errorMessage = nil
      } catch {
        guestDays = []
        errorMessage = error.localizedDescription
      }
    }

    hasLoadedForAuthState = isAuthenticated
  }

  private func sortCollections(_ items: [BangumiCollectionItem]) -> [BangumiCollectionItem] {
    items.sorted { lhs, rhs in
      if (lhs.epStatus ?? 0) != (rhs.epStatus ?? 0) {
        return (lhs.epStatus ?? 0) > (rhs.epStatus ?? 0)
      }
      if parsedDate(lhs.updatedAt) != parsedDate(rhs.updatedAt) {
        return parsedDate(lhs.updatedAt) > parsedDate(rhs.updatedAt)
      }
      return (lhs.subject.nameCN ?? lhs.subject.name) < (rhs.subject.nameCN ?? rhs.subject.name)
    }
  }

  private func parsedDate(_ value: String?) -> Date {
    guard let value, !value.isEmpty else { return .distantPast }
    let isoFormatter = ISO8601DateFormatter()
    if let date = isoFormatter.date(from: value) {
      return date
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    return formatter.date(from: value) ?? .distantPast
  }
}

private struct HomeHeader: View {
  let isAuthenticated: Bool
  let currentUser: BangumiUser?
  let onProfile: () -> Void
  let onLogin: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Bangumi")
            .font(.system(size: 30, weight: .black, design: .rounded))

          Text(isAuthenticated ? "你的收藏动态、更新进度，都在这里继续。" : "先看看每日放送和推荐条目。")
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.76))
        }

        Spacer(minLength: 12)

        if let currentUser, isAuthenticated {
          Button(action: onProfile) {
            if let avatarURL = currentUser.avatar?.best {
              CoverImage(url: avatarURL)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
              Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("打开我的页面")
        } else {
          HomeHeaderIconButton(systemImage: "person.crop.circle.badge.plus", action: onLogin)
        }
      }

      if let currentUser, isAuthenticated {
        HStack(spacing: 10) {
          SubjectCapsuleLabel(title: currentUser.displayName, systemImage: "person.fill")
        }
      }
    }
    .padding(20)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
  }
}

private struct HomeHeaderIconButton: View {
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button("操作", systemImage: systemImage, action: action)
      .labelStyle(.iconOnly)
      .font(.system(size: 20, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
  }
}

private struct HomeCategoryBar: View {
  @Binding var selection: HomeCategory

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(HomeCategory.allCases) { category in
          Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
              selection = category
            }
          } label: {
            Text(category.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(selection == category ? Color.white : Color.black.opacity(0.82))
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(
                Group {
                  if selection == category {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .fill(Color.accentColor)
                  } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .fill(Color.white.opacity(0.84))
                  }
                }
              )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 2)
    }
  }
}

private struct HomeGuestHeroCard: View {
  let onLogin: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("游客首页")
        .font(.title3.weight(.bold))

      Text("先看看每日放送和推荐条目，登录后从这里继续你的收藏动态和更新进度。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button(action: onLogin) {
        Label("登录 Bangumi", systemImage: "person.crop.circle.badge.plus")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(
      LinearGradient(
        colors: [Color.accentColor.opacity(0.18), Color.orange.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
  }
}

private struct HomeCollectionSectionView: View {
  let title: String
  let subtitle: String
  let items: [BangumiCollectionItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HomeSectionHeader(title: title, subtitle: subtitle, count: items.count)

      if #available(iOS 17.0, *) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(items) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.subjectID)
              } label: {
                HomeSubjectCard(item: item, layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .contentMargins(.horizontal, BangumiDesign.screenHorizontalPadding, for: .scrollContent)
        .scrollClipDisabled()
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(items) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.subjectID)
              } label: {
                HomeSubjectCard(item: item, layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, BangumiDesign.screenHorizontalPadding)
        }
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      }
    }
  }
}

private struct HomeGuestSectionView: View {
  let day: BangumiCalendarDay

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HomeSectionHeader(title: day.weekday.cn, subtitle: "每日放送", count: min(day.items.count, 6))

      if #available(iOS 17.0, *) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(day.items.prefix(6)) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                HomeSubjectCard(summary: item, badgeTitle: "今日放送", layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .contentMargins(.horizontal, BangumiDesign.screenHorizontalPadding, for: .scrollContent)
        .scrollClipDisabled()
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(day.items.prefix(6)) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                HomeSubjectCard(summary: item, badgeTitle: "今日放送", layout: .compact)
                  .frame(width: 212)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, BangumiDesign.screenHorizontalPadding)
        }
        .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      }
    }
  }
}

private enum HomeSubjectCardLayout {
  case rail
  case compact

  var cardHeight: CGFloat {
    switch self {
    case .rail:
      196
    case .compact:
      356
    }
  }

  var titleBlockHeight: CGFloat {
    switch self {
    case .rail:
      60
    case .compact:
      76
    }
  }
}

private struct HomeSubjectCard: View {
  private let coverURL: URL?
  private let title: String
  private let subtitle: String?
  private let score: Double?
  private let rank: Int?
  private let progressTitle: String
  private let progressValue: String
  private let badgeTitle: String
  private let ctaTitle: String
  private let layout: HomeSubjectCardLayout

  init(item: BangumiCollectionItem, layout: HomeSubjectCardLayout = .rail) {
    coverURL = item.subject.images?.best
    title = item.subject.nameCN ?? item.subject.name
    subtitle = item.subject.nameCN != nil && item.subject.nameCN != item.subject.name ? item.subject.name : nil
    score = item.subject.score
    rank = item.subject.rank
    badgeTitle = SubjectType.title(for: item.subjectType)
    ctaTitle = item.subjectType == SubjectType.anime.rawValue ? "继续追番" : "查看详情"
    self.layout = layout

    switch item.subjectType {
    case SubjectType.anime.rawValue:
      progressTitle = "追番进度"
      let total = item.subject.totalEpisodes ?? item.subject.eps ?? 0
      if total > 0 {
        progressValue = "\(item.epStatus ?? 0)/\(total) 集"
      } else {
        progressValue = "已看到第 \(item.epStatus ?? 0) 集"
      }
    case SubjectType.book.rawValue:
      progressTitle = "阅读进度"
      if let volStatus = item.volStatus, volStatus > 0 {
        progressValue = "卷 \(volStatus)"
      } else {
        progressValue = "打开书籍详情"
      }
    case SubjectType.game.rawValue:
      progressTitle = "游戏进度"
      progressValue = "继续记录"
    case SubjectType.real.rawValue:
      progressTitle = "观看进度"
      progressValue = "回到条目"
    default:
      progressTitle = "条目"
      progressValue = "查看详情"
    }
  }

  init(summary: BangumiSubjectSummary, badgeTitle: String, layout: HomeSubjectCardLayout = .rail) {
    coverURL = summary.images?.best
    title = summary.nameCN ?? summary.name
    subtitle = summary.nameCN != nil && summary.nameCN != summary.name ? summary.name : nil
    score = summary.rating?.score
    rank = summary.rating?.rank
    self.badgeTitle = badgeTitle
    ctaTitle = "查看详情"
    progressTitle = summary.date?.isEmpty == false ? "放送日期" : "条目"
    progressValue = summary.date ?? SubjectType.title(for: summary.type)
    self.layout = layout
  }

  var body: some View {
    Group {
      switch layout {
      case .rail:
        HStack(alignment: .top, spacing: 14) {
          CoverImage(url: coverURL)
            .frame(width: 88, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

          VStack(alignment: .leading, spacing: 10) {
            HomeSubjectCardMetaRow(badgeTitle: badgeTitle, rank: rank)
            HomeSubjectCardTitle(title: title, subtitle: subtitle, lineLimit: 2, layout: layout)
            HomeSubjectCardMetrics(score: score, progressTitle: progressTitle)
            Text(progressValue)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Spacer(minLength: 0)

            HStack {
              Spacer()
              HomeSubjectCardCTA(title: ctaTitle)
            }
          }
          .frame(maxHeight: .infinity, alignment: .top)
        }
      case .compact:
        VStack(alignment: .leading, spacing: 10) {
          CoverImage(url: coverURL)
            .frame(height: 138)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

          HomeSubjectCardMetaRow(badgeTitle: badgeTitle, rank: rank)
          HomeSubjectCardTitle(title: title, subtitle: subtitle, lineLimit: 2, layout: layout)
          HomeSubjectCardMetrics(score: score, progressTitle: progressTitle)

          Text(progressValue)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Spacer(minLength: 0)

          HStack {
            Spacer()
            HomeSubjectCardCTA(title: ctaTitle)
          }
        }
        .frame(maxHeight: .infinity, alignment: .top)
      }
    }
    .frame(height: layout.cardHeight, alignment: .top)
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

private struct HomeSectionHeader: View {
  let title: String
  let subtitle: String
  let count: Int

  var body: some View {
    HStack(alignment: .lastTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title3.weight(.bold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Text("\(count) 项")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.black.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.84), in: Capsule())
    }
  }
}

private struct HomeSubjectCardMetaRow: View {
  let badgeTitle: String
  let rank: Int?

  var body: some View {
    HStack {
      SubjectCapsuleLabel(title: badgeTitle, systemImage: "square.stack.fill")
      Spacer(minLength: 8)
      if let rank {
        Text("#\(rank)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct HomeSubjectCardTitle: View {
  let title: String
  let subtitle: String?
  let lineLimit: Int
  let layout: HomeSubjectCardLayout

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
        .lineLimit(lineLimit)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, minHeight: layout.titleBlockHeight, maxHeight: layout.titleBlockHeight, alignment: .topLeading)
  }
}

private struct HomeSubjectCardMetrics: View {
  let score: Double?
  let progressTitle: String

  var body: some View {
    HStack(spacing: 12) {
      if let score {
        Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
          .foregroundStyle(Color.orange)
      }
      Text(progressTitle)
        .foregroundStyle(.secondary)
    }
    .font(.caption)
  }
}

private struct HomeSubjectCardCTA: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption.weight(.bold))
      .foregroundStyle(Color.accentColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(Color.accentColor.opacity(0.12), in: Capsule())
  }
}

private struct TimelineScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = TimelineViewModel()

  var body: some View {
    ScreenScaffold(title: "时间线", subtitle: "V1 先接入全站只读列表，回复和复杂交互仍保留 Web 回退。") {
      Group {
        if viewModel.isLoading && viewModel.items.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
          UnavailableStateView(
            title: "时间线加载失败",
            systemImage: "clock.arrow.circlepath",
            message: error
          )
        } else {
          List {
            Section {
              Picker("类型", selection: $viewModel.filter) {
                ForEach(TimelineFilter.allCases) { filter in
                  Text(filter.title).tag(filter)
                }
              }
              .pickerStyle(.segmented)
            }

            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
              NavigationLink {
                timelineDestination(for: item)
              } label: {
                TimelineRow(item: item)
              }
              .task {
                await viewModel.loadMoreIfNeeded(
                  currentIndex: index,
                  using: model.timelineRepository
                )
              }
            }

            if viewModel.isLoadingMore {
              Section {
                HStack {
                  Spacer()
                  ProgressView("正在加载更多…")
                  Spacer()
                }
              }
            }
          }
          .refreshable {
            await viewModel.refresh(using: model.timelineRepository)
          }
          .bangumiRootScrollableLayout()
        }
      }
      .task {
        await viewModel.bootstrap(using: model.timelineRepository)
      }
      .onChange(of: viewModel.filter) { _ in
        Task {
          await viewModel.refresh(using: model.timelineRepository)
        }
      }
    }
  }

  @ViewBuilder
  private func timelineDestination(for item: BangumiTimelineItem) -> some View {
    if let subjectID = item.subjectID {
      SubjectDetailScreen(subjectID: subjectID)
    } else if let navigationURL = item.navigationURL {
      TimelineDetailScreen(url: navigationURL, fallbackTitle: item.targetTitle ?? "时间线详情")
    } else {
      WebFallbackScreen(
        title: item.targetTitle ?? "时间线详情",
        subtitle: item.summary,
        url: item.navigationURL
      )
    }
  }
}

private final class TimelineViewModel: ObservableObject {
  @Published var items: [BangumiTimelineItem] = []
  @Published var filter: TimelineFilter = .all
  @Published var isLoading = false
  @Published var isLoadingMore = false
  @Published var errorMessage: String?

  private var nextPage = 1
  private var hasBootstrapped = false

  @MainActor
  func bootstrap(using repository: TimelineRepository) async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    await refresh(using: repository)
  }

  @MainActor
  func refresh(using repository: TimelineRepository) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let page = try await repository.fetch(page: 1, filter: filter)
      items = page.items
      nextPage = page.nextPage ?? 1
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  func loadMoreIfNeeded(currentIndex: Int, using repository: TimelineRepository) async {
    guard !isLoading, !isLoadingMore else { return }
    guard currentIndex >= items.count - 4 else { return }
    guard nextPage > 1 else { return }

    isLoadingMore = true
    defer { isLoadingMore = false }

    do {
      let page = try await repository.fetch(page: nextPage, filter: filter)
      let existingIDs = Set(items.map(\.id))
      items.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
      nextPage = page.nextPage ?? nextPage
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct TimelineRow: View {
  let item: BangumiTimelineItem

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: item.avatarURL)
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        Text(item.summary)
          .font(.subheadline)
          .foregroundStyle(.primary)
          .lineLimit(3)

        if let comment = item.comment, !comment.isEmpty {
          Text(comment)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        if let firstImage = item.imageURLs.first {
          CoverImage(url: firstImage)
            .frame(width: 88, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        HStack(spacing: BangumiDesign.sectionSpacing) {
          if !item.date.isEmpty {
            Label(item.date, systemImage: "calendar")
          }
          if !item.time.isEmpty {
            Label(item.time, systemImage: "clock")
          }
          if let replyCount = item.replyCount {
            Label(replyCount, systemImage: "text.bubble")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct TimelineDetailScreen: View {
  let url: URL
  let fallbackTitle: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = TimelineDetailViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.detail == nil {
        ProgressView("加载中...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage, viewModel.detail == nil {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "clock.arrow.circlepath",
          message: error
        )
      } else if let detail = viewModel.detail, viewModel.hasRenderableContent {
        List {
          Section("动态") {
            TimelinePostCard(post: detail.main)
          }

          if detail.replies.isEmpty {
            Section("回复") {
              Text("当前没有解析到回复，仍可通过右上角 Safari 查看网页原文。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          } else {
            Section("回复 \(detail.replies.count)") {
              ForEach(detail.replies) { reply in
                TimelinePostCard(post: reply)
              }
            }
          }
        }
        .refreshable {
          await viewModel.refresh(using: model.timelineRepository, url: url)
        }
      } else {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "text.bubble",
          message: "暂时没有解析到动态内容，可以先用右上角 Safari 查看原文。"
        )
      }
    }
    .task(id: url.absoluteString) {
      await viewModel.load(using: model.timelineRepository, url: url)
    }
    .navigationTitle(viewModel.detail?.main.userName.isEmpty == false ? viewModel.detail?.main.userName ?? fallbackTitle : fallbackTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Link(destination: url) {
          Label("在 Safari 中打开", systemImage: "safari")
            .labelStyle(.iconOnly)
        }
      }
    }
  }
}

private final class TimelineDetailViewModel: ObservableObject {
  @Published var detail: BangumiTimelineDetail?
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var hasAttemptedLoad = false

  private var loadedURL: URL?

  var hasRenderableContent: Bool {
    guard let detail else { return false }
    let mainText = detail.main.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let mainHTML = detail.main.htmlText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !mainText.isEmpty || !mainHTML.isEmpty || !detail.replies.isEmpty
  }

  @MainActor
  func load(using repository: TimelineRepository, url: URL) async {
    if loadedURL == url, detail != nil { return }
    await refresh(using: repository, url: url)
  }

  @MainActor
  func refresh(using repository: TimelineRepository, url: URL) async {
    isLoading = true
    hasAttemptedLoad = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      detail = try await repository.fetchDetail(url: url)
      loadedURL = url
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct TimelinePostCard: View {
  let post: BangumiTimelinePost

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: post.avatarURL)
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        UserNameButton(title: post.userName, userID: post.userID)

        if let htmlText = post.htmlText, !htmlText.isEmpty {
          BangumiRichText(html: htmlText)
            .textSelection(.enabled)
        } else if !post.text.isEmpty {
          Text(post.text)
            .font(.body)
            .textSelection(.enabled)
        }

        if !post.date.isEmpty {
          Text(post.date)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct DiscoveryScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var viewModel = DiscoveryViewModel()
  @State private var heroSelection = 0
  @State private var heroAutoScrollPausedUntil: Date?
  @State private var isProgrammaticHeroSelectionChange = false
  @State private var heroFrame: CGRect = .zero

  private var featuredDay: BangumiCalendarDay? {
    let availableDays = viewModel.days.filter { !$0.items.isEmpty }
    guard !availableDays.isEmpty else { return nil }

    let calendar = Calendar(identifier: .gregorian)
    let weekday = calendar.component(.weekday, from: Date())
    let preferredNames = bangumiWeekdayNames(for: weekday)
    if let matchedByName = availableDays.first(where: { preferredNames.contains($0.weekday.cn) }) {
      return matchedByName
    }

    let preferredIDs = bangumiWeekdayIDs(for: weekday)
    if let matchedByID = availableDays.first(where: { preferredIDs.contains($0.weekday.id) }) {
      return matchedByID
    }

    return availableDays.first
  }

  private var featuredItems: [BangumiSubjectSummary] {
    featuredDay?.items ?? []
  }

  private var isHeroAutoScrollPaused: Bool {
    guard let heroAutoScrollPausedUntil else { return false }
    return heroAutoScrollPausedUntil > Date()
  }

  private var isHeroVisible: Bool {
    guard heroFrame != .zero else { return false }
    let screenBounds = UIScreen.main.bounds
    return heroFrame.maxY > 120 && heroFrame.minY < screenBounds.height - BangumiDesign.rootTabBarClearance
  }

  var body: some View {
    ScreenScaffold(
      title: "发现",
      navigationBarStyle: .discoveryNative,
      showsNavigationTitle: false
    ) {
      Group {
        if viewModel.isLoading && viewModel.days.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.days.isEmpty {
          UnavailableStateView(
            title: "加载失败",
            systemImage: "exclamationmark.triangle",
            message: error
          )
        } else {
          ZStack {
            LinearGradient(
              colors: [
                Color.accentColor.opacity(0.12),
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
              LazyVStack(alignment: .leading, spacing: BangumiDiscoveryDesign.screenSpacing) {
                if featuredDay != nil {
                  DiscoveryEditorialHeader()
                }

                if let featuredDay, !featuredItems.isEmpty {
                  if featuredItems.count == 1, let featuredItem = featuredItems.first {
                    NavigationLink {
                      SubjectDetailScreen(subjectID: featuredItem.id)
                    } label: {
                      DiscoveryHeroCard(day: featuredDay, item: featuredItem)
                    }
                    .buttonStyle(.plain)
                    .background(
                      GeometryReader { proxy in
                        Color.clear
                          .preference(key: DiscoveryHeroFramePreferenceKey.self, value: proxy.frame(in: .global))
                      }
                    )
                  } else {
                    DiscoveryHeroCarousel(
                      day: featuredDay,
                      items: featuredItems,
                      selection: $heroSelection
                    )
                  }
                }

                if let error = viewModel.errorMessage {
                  SubjectInlineMessageCard(message: error)
                }

                ForEach(viewModel.days.filter { !$0.items.isEmpty }) { day in
                  DiscoverySectionCard(day: day)
                }
              }
              .padding(.horizontal, 16)
              .padding(.top, 10)
              .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
            }
            .refreshable {
              await viewModel.load(using: model.discoveryRepository)
            }
            .onPreferenceChange(DiscoveryHeroFramePreferenceKey.self) { frame in
              heroFrame = frame
            }
          }
          .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
              .frame(height: BangumiDesign.rootTabBarClearance)
          }
        }
      }
      .task {
        await viewModel.load(using: model.discoveryRepository)
      }
      .task(id: featuredItems.map(\.id)) {
        guard featuredItems.count > 1 else { return }
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 4_800_000_000)
          guard !Task.isCancelled else { break }
          await MainActor.run {
            guard featuredItems.count > 1 else { return }
            guard scenePhase == .active else { return }
            guard isHeroVisible else { return }
            guard !isHeroAutoScrollPaused else { return }
            advanceHeroCarousel()
          }
        }
      }
      .onChange(of: featuredItems.map(\.id)) { ids in
        guard !ids.isEmpty else {
          heroSelection = 0
          return
        }
        heroSelection = min(heroSelection, ids.count - 1)
      }
      .onChange(of: heroSelection) { _ in
        guard featuredItems.count > 1 else { return }
        guard !isProgrammaticHeroSelectionChange else { return }
        pauseHeroAutoScroll()
      }
    }
  }

  private func advanceHeroCarousel() {
    guard featuredItems.count > 1 else { return }
    isProgrammaticHeroSelectionChange = true
    heroSelection = (heroSelection + 1) % featuredItems.count
    DispatchQueue.main.async {
      isProgrammaticHeroSelectionChange = false
    }
  }

  private func pauseHeroAutoScroll() {
    heroAutoScrollPausedUntil = Date().addingTimeInterval(6)
  }

  private func bangumiWeekdayNames(for systemWeekday: Int) -> [String] {
    switch systemWeekday {
    case 1:
      ["星期日", "星期天", "周日", "周天"]
    case 2:
      ["星期一", "周一"]
    case 3:
      ["星期二", "周二"]
    case 4:
      ["星期三", "周三"]
    case 5:
      ["星期四", "周四"]
    case 6:
      ["星期五", "周五"]
    case 7:
      ["星期六", "周六"]
    default:
      []
    }
  }

  private func bangumiWeekdayIDs(for systemWeekday: Int) -> [Int] {
    let mondayFirst = ((systemWeekday + 5) % 7) + 1
    return [mondayFirst, systemWeekday]
  }
}

private struct DiscoveryHeroFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

private struct DiscoveryTopBar: View {
  let onNotifications: () -> Void
  let onSearch: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button("通知", systemImage: "bell") {
        onNotifications()
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 52, height: 52)

      Divider()
        .frame(height: 24)

      Button("搜索", systemImage: "magnifyingglass") {
        onSearch()
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 52, height: 52)
    }
    .background(.thinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(Color.white.opacity(0.38), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
  }
}

private struct DiscoveryEditorialHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(BangumiDiscoveryCopy.heroEyebrow)
        .font(.caption.weight(.bold))
        .tracking(1.3)
        .foregroundStyle(.secondary)

      Text(BangumiDiscoveryCopy.heroTitle)
        .font(.system(size: 32, weight: .black, design: .rounded))
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct DiscoveryHeroCarousel: View {
  let day: BangumiCalendarDay
  let items: [BangumiSubjectSummary]
  @Binding var selection: Int
  @State private var scrollTargetID: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if #available(iOS 17.0, *) {
        modernCarousel
      } else {
        legacyCarousel
      }

      HStack(spacing: 10) {
        HStack(spacing: 7) {
          ForEach(Array(items.indices), id: \.self) { index in
            Capsule()
              .fill(index == selection ? Color.primary : Color.primary.opacity(0.18))
              .frame(width: index == selection ? 18 : 7, height: 7)
          }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: selection)

        Spacer(minLength: 12)

        Text("\(selection + 1) / \(items.count)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 6)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("今日主打轮播，第 \(selection + 1) 页，共 \(items.count) 页")
    }
  }

  @available(iOS 17.0, *)
  private var modernCarousel: some View {
    GeometryReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: BangumiDiscoveryDesign.cardSpacing) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            NavigationLink {
              SubjectDetailScreen(subjectID: item.id)
            } label: {
              DiscoveryHeroCard(day: day, item: item)
            }
            .buttonStyle(.plain)
            .frame(
              width: max(
                proxy.size.width,
                1
              )
            )
            .id(index)
          }
        }
        .scrollTargetLayout()
      }
      .contentMargins(.horizontal, BangumiDiscoveryDesign.heroPageInset, for: .scrollContent)
      .scrollClipDisabled()
      .padding(.horizontal, -BangumiDesign.screenHorizontalPadding)
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
      .scrollPosition(id: $scrollTargetID)
      .background(
        GeometryReader { scrollProxy in
          Color.clear
            .preference(key: DiscoveryHeroFramePreferenceKey.self, value: scrollProxy.frame(in: .global))
        }
      )
      .onAppear {
        scrollTargetID = selection
      }
      .onChange(of: selection) { newValue in
        guard scrollTargetID != newValue else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
          scrollTargetID = newValue
        }
      }
      .onChange(of: scrollTargetID) { newValue in
        guard let newValue, selection != newValue else { return }
        selection = newValue
      }
    }
    .frame(height: BangumiDiscoveryDesign.heroHeight)
  }

  private var legacyCarousel: some View {
    TabView(selection: $selection) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        NavigationLink {
          SubjectDetailScreen(subjectID: item.id)
        } label: {
          DiscoveryHeroCard(day: day, item: item)
            .padding(.horizontal, BangumiDiscoveryDesign.heroPageInset)
        }
        .buttonStyle(.plain)
        .tag(index)
      }
    }
    .frame(height: BangumiDiscoveryDesign.heroHeight)
    .tabViewStyle(.page(indexDisplayMode: .never))
    .background(
      GeometryReader { proxy in
        Color.clear
          .preference(key: DiscoveryHeroFramePreferenceKey.self, value: proxy.frame(in: .global))
      }
    )
  }
}

private struct DiscoveryHeroCard: View {
  let day: BangumiCalendarDay
  let item: BangumiSubjectSummary

  private var title: String {
    item.nameCN ?? item.name
  }

  private var subtitle: String? {
    guard let localized = item.nameCN, localized != item.name else {
      return nil
    }
    return item.name
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      CoverImage(url: item.images?.best)
        .frame(maxWidth: .infinity)
        .frame(height: BangumiDiscoveryDesign.heroHeight)

      LinearGradient(
        colors: [
          Color.black.opacity(0.04),
          Color.black.opacity(0.2),
          Color.black.opacity(0.78),
          Color.black.opacity(0.94)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      VStack(alignment: .leading, spacing: 14) {
        Spacer(minLength: 24)

        HStack(spacing: 8) {
          DiscoveryBadge(title: day.weekday.cn, systemImage: "calendar")

          if let date = item.date, !date.isEmpty {
            DiscoveryBadge(title: date, systemImage: "clock")
          }

          if let score = item.rating?.score {
            DiscoveryBadge(
              title: score.formatted(.number.precision(.fractionLength(1))),
              systemImage: "star.fill"
            )
          }
        }

        Text(title)
          .font(.system(size: 34, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.headline)
            .foregroundStyle(Color.white.opacity(0.86))
            .lineLimit(2)
        }
      }
      .padding(22)
    }
    .clipShape(RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.heroRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.heroRadius, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title)，\(day.weekday.cn)主打")
  }
}

private struct DiscoverySectionCard: View {
  let day: BangumiCalendarDay

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(BangumiDiscoveryCopy.sectionEyebrow)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)

          Text(day.weekday.cn)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(.primary)

          Text(BangumiDiscoveryCopy.sectionSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Text("\(day.items.count) 部")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.white.opacity(0.58), in: Capsule())
      }

      VStack(spacing: 12) {
        ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
          NavigationLink {
            SubjectDetailScreen(subjectID: item.id)
          } label: {
            DiscoveryRowCard(item: item)
          }
          .buttonStyle(.plain)

          if index != day.items.count - 1 {
            Divider()
              .padding(.horizontal, 6)
          }
        }
      }
    }
    .padding(BangumiDiscoveryDesign.sectionPadding)
    .background(
      LinearGradient(
        colors: [
          Color(uiColor: .secondarySystemGroupedBackground),
          Color(uiColor: .systemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.sectionRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.sectionRadius, style: .continuous)
        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
    }
  }
}

private struct DiscoveryRowCard: View {
  let item: BangumiSubjectSummary

  private var title: String {
    item.nameCN ?? item.name
  }

  private var subtitle: String? {
    guard let localized = item.nameCN, localized != item.name else {
      return nil
    }
    return item.name
  }

  private var episodeText: String? {
    let total = item.totalEpisodes ?? item.eps
    guard let total, total > 0 else {
      return nil
    }
    return "\(total) 集"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CoverImage(url: item.images?.best)
        .frame(width: BangumiDiscoveryDesign.rowCoverWidth, height: BangumiDiscoveryDesign.rowCoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          if let score = item.rating?.score {
            Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
              .foregroundStyle(Color.orange)
          }

          if let episodeText {
            Label(episodeText, systemImage: "play.tv")
              .foregroundStyle(.secondary)
          }
        }
        .font(.caption.weight(.semibold))

        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        HStack(spacing: 10) {
          if let date = item.date, !date.isEmpty {
            Label(date, systemImage: "calendar")
              .foregroundStyle(.secondary)
          } else {
            Label(SubjectType.title(for: item.type), systemImage: "square.stack")
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          Text("查看详情")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)
        }
        .font(.caption)
      }

      Spacer(minLength: 10)

      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
    }
    .padding(BangumiDiscoveryDesign.rowPadding)
    .background(
      Color(uiColor: .tertiarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: BangumiDiscoveryDesign.rowRadius, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
  }
}

private struct DiscoveryBadge: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.16), in: Capsule())
  }
}

private final class DiscoveryViewModel: ObservableObject {
  @Published var days: [BangumiCalendarDay] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  @MainActor
  func load(using repository: DiscoveryRepository) async {
    isLoading = true
    defer { isLoading = false }

    do {
      days = try await repository.fetchCalendar()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct SearchScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @StateObject private var viewModel = SearchViewModel()

  var body: some View {
    List {
      Section {
        Picker("类型", selection: $viewModel.subjectType) {
          ForEach(SubjectType.allCases) { type in
            Text(type.title).tag(type)
          }
        }
        .pickerStyle(.menu)

        Toggle(
          "模糊搜索",
          isOn: Binding(
            get: { viewModel.matchMode.isFuzzy },
            set: { isOn in
              let nextMode: BangumiSearchMatchMode = isOn ? .fuzzy : .precise
              guard nextMode != viewModel.matchMode else { return }
              viewModel.matchMode = nextMode
            }
          )
        )

        Button("查询", action: submitSearch)
          .disabled(model.searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if !settingsStore.recentSearches.isEmpty {
        Section("最近搜索") {
          ForEach(settingsStore.recentSearches, id: \.self) { item in
            Button(item) {
              model.searchDraft = item
              submitSearch()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button("删除", role: .destructive) {
                settingsStore.removeSearch(item)
              }
            }
          }

          Button("清除历史", role: .destructive) {
            settingsStore.clearSearches()
          }
        }
      }

      if viewModel.isLoading {
        Section {
          ProgressView(viewModel.lastSubmittedKeyword.isEmpty ? "正在搜索..." : "正在搜索 “\(viewModel.lastSubmittedKeyword)” …")
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
      else if let error = viewModel.errorMessage, viewModel.hasSearched {
        Section("错误") {
          Text(error)
            .foregroundStyle(.red)
          Button("重试", action: submitSearch)
        }
      }
      else if viewModel.hasSearched {
        Section("结果") {
          if viewModel.results.isEmpty {
            UnavailableStateView(
              title: "没有找到匹配条目",
              systemImage: "magnifyingglass",
              message: "换个关键词、切换类型，或试试打开模糊搜索。"
            )
            .frame(maxWidth: .infinity, minHeight: 180)
            .listRowBackground(Color.clear)
          } else {
            ForEach(viewModel.results) { item in
              NavigationLink {
                SubjectDetailScreen(subjectID: item.id)
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  SubjectRow(item: item)

                  if let searchMeta = item.searchMeta, !searchMeta.isEmpty {
                    Text(searchMeta)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                      .padding(.leading, 68)
                  }
                }
                .padding(.vertical, 4)
              }
            }
          }
        }
      }
      else if settingsStore.recentSearches.isEmpty {
        Section {
          UnavailableStateView(
            title: "开始搜索",
            systemImage: "magnifyingglass",
            message: "先选类型，输入关键词，再决定要不要打开模糊搜索。"
          )
          .frame(maxWidth: .infinity, minHeight: 180)
          .listRowBackground(Color.clear)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("搜索")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if let latest = settingsStore.recentSearches.first, model.searchDraft.isEmpty {
            Button("恢复最近一次输入") {
              model.searchDraft = latest
            }
          }

          if !model.searchDraft.isEmpty {
            Button("清空输入") {
              clearSearchQuery()
            }
          }

          if !settingsStore.recentSearches.isEmpty {
            Button("清空搜索历史", role: .destructive) {
              settingsStore.clearSearches()
            }
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }
    }
    .task {
      syncSearchDraft()
    }
    .task(id: model.searchShouldAutoSubmit) {
      guard model.searchShouldAutoSubmit else { return }
      submitSearch()
      model.searchShouldAutoSubmit = false
    }
    .onChange(of: model.searchDraft) { _, newValue in
      viewModel.keyword = newValue
      viewModel.resetResultsIfNeeded()
    }
    .onChange(of: model.searchSubmissionSequence) { _, _ in
      submitSearch()
    }
    .onChange(of: viewModel.matchMode) { _, _ in
      guard viewModel.hasSearched else { return }
      submitSearch()
    }
  }

  private func submitSearch() {
    syncSearchDraft()
    let trimmed = model.searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      viewModel.resetResultsIfNeeded()
      return
    }
    Task {
      await viewModel.search(using: model.searchRepository, settings: settingsStore)
    }
  }

  private func syncSearchDraft() {
    viewModel.keyword = model.searchDraft
  }

  private func clearSearchQuery() {
    model.searchDraft = ""
    viewModel.clearKeyword()
    viewModel.resetResultsIfNeeded()
  }
}

private final class SearchViewModel: ObservableObject {
  @Published var keyword = ""
  @Published var subjectType: SubjectType = .anime
  @Published var matchMode: BangumiSearchMatchMode = .precise
  @Published var results: [BangumiSubjectSummary] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published private(set) var hasSearched = false
  @Published private(set) var lastSubmittedKeyword = ""

  func toggleMatchMode() {
    matchMode = matchMode == .precise ? .fuzzy : .precise
  }

  func clearKeyword() {
    keyword = ""
  }

  func resetResultsIfNeeded() {
    guard keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    results = []
    errorMessage = nil
    hasSearched = false
    lastSubmittedKeyword = ""
  }

  @MainActor
  func search(using repository: SearchRepository, settings: BangumiSettingsStore) async {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    isLoading = true
    errorMessage = nil
    hasSearched = true
    lastSubmittedKeyword = trimmed
    defer { isLoading = false }

    do {
      results = try await repository.search(
        query: BangumiSearchQuery(
          keyword: trimmed,
          type: subjectType,
          matchMode: matchMode
        )
      )
      settings.rememberSearch(trimmed)
      errorMessage = results.isEmpty ? "没有找到匹配条目。" : nil
    } catch {
      results = []
      errorMessage = error.localizedDescription
    }
  }
}

private enum SubjectDetailContentTab: String, CaseIterable, Identifiable {
  case overview
  case details

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: "简介"
    case .details: "详情"
    }
  }
}

private struct SubjectDetailScreen: View {
  let subjectID: Int

  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @StateObject private var viewModel = SubjectDetailViewModel()
  @State private var isShowingEditor = false
  @State private var isShowingFullSummary = false
  @State private var isShowingAllTags = false
  @State private var selectedContentTab: SubjectDetailContentTab = .overview

  var body: some View {
    ScreenScaffold(
      title: viewModel.navigationTitle,
      subtitle: nil,
      navigationBarStyle: .discoveryNative
    ) {
      Group {
        if viewModel.isLoading && viewModel.subject == nil {
          ProgressView("正在加载条目...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.subject == nil {
          UnavailableStateView(
            title: "条目详情",
            systemImage: "exclamationmark.triangle",
            message: error
          )
        } else if let subject = viewModel.subject {
          let notificationSubscription = notificationStore.subscription(for: subjectID)
          let presentation = viewModel.presentation

          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              SubjectHeroCard(
                subject: subject,
                collectionTitle: viewModel.collection.map { viewModel.collectionTitle(from: $0) },
                watchedEpisodes: viewModel.watchedEpisodes
              )

              if let error = viewModel.errorMessage {
                SubjectInlineMessageCard(message: error)
              }

              SubjectActionCard(
                subjectType: subject.type,
                isAuthenticated: sessionStore.isAuthenticated,
                collectionTitle: viewModel.collection.map { viewModel.collectionTitle(from: $0) },
                progressValue: subject.type == SubjectType.book.rawValue ? (viewModel.collection?.volStatus ?? 0) : viewModel.watchedEpisodes,
                totalProgress: subject.type == SubjectType.book.rawValue ? (subject.volumes ?? 0) : max(viewModel.episodes.count, subject.totalEpisodes ?? subject.eps ?? 0),
                notificationPermissionState: notificationStore.permissionState,
                notificationSubscription: notificationSubscription,
                isNotificationUpdating: notificationStore.updatingSubjectIDs.contains(subjectID),
                onEditCollection: {
                  isShowingEditor = true
                },
                onToggleNotifications: {
                  Task {
                    await notificationStore.toggleSubscription(subject: subject, episodes: viewModel.episodes)
                  }
                }
              )

              if !viewModel.episodes.isEmpty {
                SubjectEpisodeProgressSection(
                  episodes: viewModel.episodes,
                  statuses: viewModel.episodeStatuses,
                  watchedEpisodes: viewModel.watchedEpisodes,
                  isAuthenticated: sessionStore.isAuthenticated,
                  updatingEpisodeID: viewModel.updatingEpisodeID,
                  onSelectStatus: { episode, status in
                    Task {
                      _ = await viewModel.updateEpisodeStatus(
                        using: model.subjectRepository,
                        subjectID: subjectID,
                        episode: episode,
                        status: status,
                        isAuthenticated: sessionStore.isAuthenticated
                      )
                    }
                  }
                )
              }

              SubjectDetailTabBar(selection: $selectedContentTab)

              switch selectedContentTab {
              case .overview:
                if let summary = subject.summary, !summary.isEmpty {
                  SubjectSummarySection(
                    summary: summary,
                    isExpanded: $isShowingFullSummary
                  )
                }

                if !presentation.previews.isEmpty {
                  SubjectPreviewSection(items: presentation.previews, moreURL: presentation.morePreviewsURL)
                }

                if let tags = subject.tags, !tags.isEmpty {
                  SubjectTagsSection(
                    tags: tags,
                    isExpanded: $isShowingAllTags
                  )
                }

                SubjectCommentsSection(
                  comments: viewModel.comments,
                  isLoading: viewModel.isLoadingComments,
                  errorMessage: viewModel.commentsErrorMessage,
                  moreURL: URL(string: "https://bgm.tv/subject/\(subjectID)/comments")
                )

              case .details:
                if viewModel.isLoadingPresentation {
                  SubjectDetailLoadingSection()
                } else if !presentation.infoEntries.isEmpty {
                  SubjectDetailInfoSection(entries: presentation.infoEntries)
                } else {
                  SubjectInfoGridCard(subject: subject)
                }

                if let ratingBreakdown = presentation.ratingBreakdown ?? SubjectRatingSection.fallbackBreakdown(from: subject) {
                  SubjectRatingSection(
                    breakdown: ratingBreakdown,
                    moreURL: presentation.statsURL
                  )
                }

                if let collection = subject.collection {
                  SubjectCollectionStatsSection(stats: collection)
                }

                if !presentation.cast.isEmpty {
                  SubjectCastSection(items: presentation.cast, moreURL: presentation.moreCastURL)
                }

                if !presentation.staff.isEmpty {
                  SubjectStaffSection(items: presentation.staff, moreURL: presentation.moreStaffURL)
                }

                if !presentation.relations.isEmpty {
                  SubjectRelationSection(items: presentation.relations, moreURL: presentation.moreRelationsURL)
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, BangumiDesign.rootTabBarClearance + 12)
          }
          .refreshable {
            await viewModel.load(
              subjectID: subjectID,
              repository: model.subjectRepository,
              isAuthenticated: sessionStore.isAuthenticated
            )
          }
        }
      }
    }
    .task {
      await viewModel.load(subjectID: subjectID, repository: model.subjectRepository, isAuthenticated: sessionStore.isAuthenticated)
    }
    .sheet(isPresented: $isShowingEditor) {
      if let subject = viewModel.subject {
        NavigationStack {
          CollectionEditorScreen(
            title: subject.nameCN ?? subject.name,
            subjectType: subject.type,
            totalEpisodes: max(viewModel.episodes.count, subject.totalEpisodes ?? subject.eps ?? 0),
            totalVolumes: subject.volumes ?? 0,
            initialPayload: viewModel.editorPayload,
            onSave: { payload in
              Task {
                await viewModel.saveCollection(using: model.subjectRepository, subjectID: subjectID, payload: payload)
              }
            }
          )
        }
      }
    }
  }
}

private struct SubjectHeroCard: View {
  let subject: BangumiSubject
  let collectionTitle: String?
  let watchedEpisodes: Int

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.18),
              Color(uiColor: .secondarySystemGroupedBackground),
              Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top, spacing: 18) {
          Button {
            if let url = subject.images?.best {
              model.presentImage(url)
            }
          } label: {
            CoverImage(url: subject.images?.best)
              .frame(width: 138, height: 196)
              .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
              .overlay(alignment: .bottomTrailing) {
                if subject.nsfw == true {
                  SubjectHeroBadge(title: "NSFW", systemImage: "eye.slash")
                    .padding(10)
                }
              }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("查看封面")

          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
              SubjectCapsuleLabel(title: SubjectType.title(for: subject.type), systemImage: "square.stack")
              if let year = subject.date?.split(separator: "-").first, !year.isEmpty {
                SubjectCapsuleLabel(title: String(year), systemImage: "calendar")
              }
            }

            Text(subject.nameCN ?? subject.name)
              .font(.system(size: 29, weight: .bold, design: .rounded))
              .foregroundStyle(.primary)
              .fixedSize(horizontal: false, vertical: true)

            if let localizedName = subject.nameCN, localizedName != subject.name {
              Text(subject.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
              if let score = subject.rating?.score {
                Text(score, format: .number.precision(.fractionLength(1)))
                  .font(.system(size: 32, weight: .bold, design: .rounded))
                  .foregroundStyle(.primary)
              }

              VStack(alignment: .leading, spacing: 4) {
                if let rank = subject.rating?.rank {
                  Text("Rank #\(rank)")
                    .font(.subheadline.weight(.semibold))
                }
                if let total = subject.rating?.total {
                  Text("\(total) 人评分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }

            if let collectionTitle {
              Label(collectionTitle, systemImage: "books.vertical")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            }
          }
        }

      }
      .padding(20)
    }
  }
}

private struct SubjectActionCard: View {
  let subjectType: Int?
  let isAuthenticated: Bool
  let collectionTitle: String?
  let progressValue: Int
  let totalProgress: Int
  let notificationPermissionState: BangumiNotificationPermissionState
  let notificationSubscription: BangumiSubjectNotificationSubscription?
  let isNotificationUpdating: Bool
  let onEditCollection: () -> Void
  let onToggleNotifications: () -> Void

  @Environment(\.openURL) private var openURL

  private var notificationButtonTitle: String {
    notificationSubscription == nil ? "开启更新提醒" : "关闭更新提醒"
  }

  private var notificationStatusTitle: String {
    if notificationSubscription != nil {
      return notificationPermissionState.canDeliverNotifications ? "新章节会推送到系统通知" : "已订阅，等待系统通知授权"
    }
    return "只在本条目有新章节时提醒"
  }

  private var progressUnitTitle: String {
    if subjectType == SubjectType.book.rawValue {
      return "卷"
    }
    return "集"
  }

  private var progressChipTitle: String {
    if totalProgress > 0 {
      return "\(progressValue) / \(totalProgress) \(progressUnitTitle)"
    }
    return "\(progressValue) \(progressUnitTitle)"
  }

  private var syncChipTitle: String {
    if subjectType == SubjectType.book.rawValue {
      return "卷同步"
    }
    return "逐集同步"
  }

  var body: some View {
    SubjectSectionCard(title: "收藏") {
      VStack(alignment: .leading, spacing: 14) {
        if let collectionTitle {
          HStack {
            Label("当前状态", systemImage: "heart.text.square")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            Spacer()

            Text(collectionTitle)
              .font(.subheadline.weight(.semibold))
          }
        }

        if isAuthenticated {
          Button(action: onEditCollection) {
            HStack {
              Label("编辑收藏", systemImage: "square.and.pencil")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)

          HStack(spacing: 10) {
            SubjectCollectionSummaryChip(
              title: progressChipTitle,
              systemImage: "square.grid.3x2"
            )
            SubjectCollectionSummaryChip(
              title: syncChipTitle,
              systemImage: "sparkles"
            )
          }
        } else {
          Text("登录后可以编辑收藏、同步评分和更新进度。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Divider()

        VStack(alignment: .leading, spacing: 10) {
          Button(action: onToggleNotifications) {
            HStack(spacing: 12) {
              Image(systemName: notificationSubscription == nil ? "bell.badge" : "bell.badge.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(notificationSubscription == nil ? Color.accentColor : Color.orange)
                .frame(width: 28)

              VStack(alignment: .leading, spacing: 4) {
                Text(notificationButtonTitle)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.primary)

                Text(notificationStatusTitle)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer(minLength: 12)

              if isNotificationUpdating {
                ProgressView()
                  .controlSize(.small)
              } else {
                Text(notificationSubscription == nil ? "未开启" : "已开启")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(notificationSubscription == nil ? .secondary : Color.orange)
              }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)

          if notificationPermissionState == .denied || notificationPermissionState == .notDetermined {
            HStack(spacing: 8) {
              Image(systemName: notificationPermissionState.systemImage)
                .foregroundStyle(notificationPermissionState.canDeliverNotifications ? Color.orange : Color.secondary)

              Text(notificationPermissionState.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

              Spacer(minLength: 8)

              if notificationPermissionState == .denied {
                Button("去设置") {
                  guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                  openURL(url)
                }
                .font(.caption.weight(.semibold))
              }
            }
          }
        }
      }
    }
  }
}

private struct SubjectDetailTabBar: View {
  @Binding var selection: SubjectDetailContentTab

  var body: some View {
    Picker("条目内容", selection: $selection) {
      ForEach(SubjectDetailContentTab.allCases) { tab in
        Text(tab.title)
          .tag(tab)
      }
    }
    .pickerStyle(.segmented)
  }
}

private struct SubjectPlainSection<Content: View>: View {
  let title: String
  let actionTitle: String?
  let action: (() -> Void)?
  let content: Content

  init(
    title: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.actionTitle = actionTitle
    self.action = action
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(title)
          .font(BangumiTypography.detailFont(size: 22, weight: .bold))
          .foregroundStyle(.primary)

        Spacer(minLength: 8)

        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .font(BangumiTypography.detailFont(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
      }

      content
    }
  }
}

private struct SubjectSummarySection: View {
  let summary: String
  @Binding var isExpanded: Bool

  private var shouldCollapse: Bool {
    summary.count > 140
  }

  var body: some View {
    SubjectPlainSection(title: "简介") {
      VStack(alignment: .leading, spacing: 12) {
        Text(summary)
          .font(BangumiTypography.detailFont(size: 17))
          .foregroundStyle(.primary)
          .lineSpacing(6)
          .lineLimit(isExpanded ? nil : 5)
          .textSelection(.enabled)

        if shouldCollapse {
          SubjectDisclosureButton(
            title: isExpanded ? "收起简介" : "展开简介",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectPreviewSection: View {
  let items: [BangumiSubjectPreviewItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "预览",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 14) {
          ForEach(items) { item in
            Button {
              if let imageURL = item.imageURL {
                model.presentImage(imageURL)
              } else if let targetURL = item.targetURL {
                model.present(url: targetURL)
              }
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                CoverImage(url: item.imageURL)
                  .frame(width: 262, height: 156)
                  .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(item.title)
                  .font(.headline.weight(.semibold))
                  .foregroundStyle(.primary)
                  .lineLimit(1)

                if let caption = item.caption, !caption.isEmpty {
                  Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              .frame(width: 262, alignment: .leading)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectTagsSection: View {
  let tags: [BangumiTag]
  @Binding var isExpanded: Bool

  private var displayedTags: [BangumiTag] {
    if isExpanded || tags.count <= 12 {
      return tags
    }
    return Array(tags.prefix(12))
  }

  var body: some View {
    SubjectPlainSection(title: "标签") {
      VStack(alignment: .leading, spacing: 12) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(displayedTags, id: \.self) { tag in
            SubjectTagChip(tag: tag)
          }
        }

        if tags.count > 12 {
          SubjectDisclosureButton(
            title: isExpanded ? "收起标签" : "展开全部 \(tags.count) 个标签",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectDetailInfoSection: View {
  let entries: [BangumiSubjectInfoEntry]

  var body: some View {
    SubjectPlainSection(title: "详情") {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          SubjectDetailInfoRow(entry: entry)

          if index < entries.count - 1 {
            Divider()
              .padding(.leading, 104)
          }
        }
      }
    }
  }
}

private struct SubjectDetailLoadingSection: View {
  var body: some View {
    SubjectPlainSection(title: "详情") {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        Text("正在整理详情和职员表…")
          .font(BangumiTypography.detailFont(size: 16))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
    }
  }
}

private struct SubjectDetailInfoRow: View {
  let entry: BangumiSubjectInfoEntry

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Text(entry.label)
        .font(BangumiTypography.detailFont(size: 17, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 90, alignment: .leading)

      BangumiInlineRichText(
        html: entry.htmlValue,
        fallback: entry.textValue
      )
      .font(.body)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct BangumiInlineRichText: View {
  let html: String?
  let fallback: String
  private let baseURL = URL(string: "https://bgm.tv")!

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    Group {
      if let html,
         let attributed = BangumiHTMLParser.attributedString(from: html, baseURL: baseURL),
         !attributed.characters.isEmpty {
        Text(normalizedAttributedString(from: attributed))
          .foregroundStyle(.primary)
          .tint(BangumiTypography.detailLinkColor)
          .lineSpacing(4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      } else {
        Text(fallback)
          .font(BangumiTypography.detailFont(size: 17))
          .foregroundStyle(.primary)
          .lineSpacing(4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      model.present(url: url)
      return .handled
    })
  }

  private func normalizedAttributedString(from attributed: AttributedString) -> AttributedString {
    let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.addAttribute(
      .font,
      value: BangumiTypography.detailUIFont(size: 17),
      range: fullRange
    )
    mutable.addAttribute(
      .foregroundColor,
      value: UIColor.label,
      range: fullRange
    )

    mutable.enumerateAttribute(.link, in: fullRange) { value, range, _ in
      guard value != nil else { return }
      mutable.addAttribute(
        .foregroundColor,
        value: BangumiTypography.detailLinkUIColor,
        range: range
      )
      mutable.addAttribute(
        .underlineStyle,
        value: 0,
        range: range
      )
    }

    if let normalized = try? AttributedString(mutable, including: \.uiKit) {
      return normalized
    }

    return attributed
  }
}

private struct SubjectRatingSection: View {
  let breakdown: BangumiSubjectRatingBreakdown
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  static func fallbackBreakdown(from subject: BangumiSubject) -> BangumiSubjectRatingBreakdown? {
    guard subject.rating?.score != nil || subject.rating?.rank != nil || subject.rating?.total != nil else {
      return nil
    }

    return BangumiSubjectRatingBreakdown(
      average: subject.rating?.score,
      rank: subject.rating?.rank,
      totalVotes: subject.rating?.total,
      buckets: [],
      externalRatings: []
    )
  }

  var body: some View {
    SubjectPlainSection(
      title: "评分",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          if let average = breakdown.average {
            Text(average, format: .number.precision(.fractionLength(1)))
              .font(.system(size: 42, weight: .black, design: .rounded))
              .foregroundStyle(Color.orange)
          }

          if let rank = breakdown.rank {
            Text("\(rank)")
              .font(.headline.weight(.bold))
              .foregroundStyle(.primary)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }

          Spacer(minLength: 8)

          if let totalVotes = breakdown.totalVotes {
            Text("\(totalVotes) votes")
              .font(.headline.weight(.semibold))
              .foregroundStyle(.secondary)
          }
        }

        if !breakdown.buckets.isEmpty {
          SubjectRatingHistogram(buckets: breakdown.buckets)
        }

        if !breakdown.externalRatings.isEmpty {
          HStack(spacing: 10) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
              ForEach(breakdown.externalRatings) { rating in
                HStack(spacing: 6) {
                  Text(rating.source + ":")
                    .foregroundStyle(.secondary)
                  Text(rating.scoreText)
                    .foregroundStyle(.primary)
                  if let votesText = rating.votesText, !votesText.isEmpty {
                    Text("(\(votesText))")
                      .foregroundStyle(.secondary)
                  }
                }
                .font(.footnote.weight(.medium))
              }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectRatingHistogram: View {
  let buckets: [BangumiSubjectRatingBucket]

  private var maxCount: Int {
    buckets.map(\.count).max() ?? 1
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 14) {
      ForEach(buckets) { bucket in
        VStack(spacing: 8) {
          Text("\(bucket.count)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)

          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(0.7))
            .frame(width: 14, height: max(8, CGFloat(bucket.count) / CGFloat(maxCount) * 128))

          Text("\(bucket.score)")
            .font(.headline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 4)
  }
}

private struct SubjectCollectionStatsSection: View {
  let stats: BangumiSubjectCollectionStats

  var body: some View {
    let items = [
      ("在看", stats.doing ?? 0),
      ("看过", stats.collect ?? 0),
      ("想看", stats.wish ?? 0),
      ("搁置", stats.onHold ?? 0),
      ("抛弃", stats.dropped ?? 0)
    ]
    .filter { $0.1 > 0 }

    if !items.isEmpty {
      SubjectPlainSection(title: "收藏概览") {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 88), spacing: 10)],
          spacing: 10
        ) {
          ForEach(items, id: \.0) { item in
            VStack(alignment: .leading, spacing: 6) {
              Text(item.0)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("\(item.1)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectCastSection: View {
  let items: [BangumiSubjectCastItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "角色",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Button {
              if let detailURL = item.detailURL {
                model.present(url: detailURL)
              }
            } label: {
              SubjectPersonRailCard(
                imageURL: item.imageURL,
                title: item.name,
                subtitle: item.subtitle,
                role: item.actorName ?? item.role,
                accentText: item.accentText
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectStaffSection: View {
  let items: [BangumiSubjectStaffItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "制作人员",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Button {
              if let detailURL = item.detailURL {
                model.present(url: detailURL)
              }
            } label: {
              SubjectPersonRailCard(
                imageURL: item.imageURL,
                title: item.name,
                subtitle: item.subtitle,
                role: item.roles,
                accentText: item.accentText
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SubjectRelationSection: View {
  let items: [BangumiSubjectRelationItem]
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "关联",
      actionTitle: moreURL == nil ? nil : "更多",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            Group {
              if let subjectID = item.subjectID {
                NavigationLink {
                  SubjectDetailScreen(subjectID: subjectID)
                } label: {
                  SubjectRelationRailCard(item: item)
                }
                .buttonStyle(.plain)
              } else {
                Button {
                  if let detailURL = item.detailURL {
                    model.present(url: detailURL)
                  }
                } label: {
                  SubjectRelationRailCard(item: item)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
      }
    }
  }
}

private struct SubjectPersonRailCard: View {
  let imageURL: URL?
  let title: String
  let subtitle: String?
  let role: String?
  let accentText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      CoverImage(url: imageURL)
        .frame(width: 104, height: 134)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let role, !role.isEmpty {
        Text(role)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      if let accentText, !accentText.isEmpty {
        Text(accentText)
          .font(.headline.weight(.bold))
          .foregroundStyle(.pink)
      }
    }
    .frame(width: 104, alignment: .topLeading)
  }
}

private struct SubjectRelationRailCard: View {
  let item: BangumiSubjectRelationItem

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      CoverImage(url: item.imageURL)
        .frame(width: 118, height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(item.title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      if let subtitle = item.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let relationLabel = item.relationLabel, !relationLabel.isEmpty {
        Text(relationLabel)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.pink)
          .lineLimit(1)
      }
    }
    .frame(width: 118, alignment: .topLeading)
  }
}

private struct SubjectTagsCard: View {
  let tags: [BangumiTag]
  @Binding var isExpanded: Bool

  private var displayedTags: [BangumiTag] {
    if isExpanded || tags.count <= 8 {
      return tags
    }
    return Array(tags.prefix(8))
  }

  var body: some View {
    SubjectSectionCard(title: "标签") {
      VStack(alignment: .leading, spacing: 12) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(displayedTags, id: \.self) { tag in
            SubjectTagChip(tag: tag)
          }
        }

        if tags.count > 8 {
          SubjectDisclosureButton(
            title: isExpanded ? "收起标签" : "展开全部 \(tags.count) 个标签",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectSummaryCard: View {
  let summary: String
  @Binding var isExpanded: Bool

  private var shouldCollapse: Bool {
    summary.count > 140
  }

  var body: some View {
    SubjectSectionCard(title: "简介") {
      VStack(alignment: .leading, spacing: 12) {
        Text(summary)
          .font(.body)
          .foregroundStyle(.primary)
          .lineSpacing(5)
          .lineLimit(isExpanded ? nil : 4)
          .textSelection(.enabled)

        if shouldCollapse {
          SubjectDisclosureButton(
            title: isExpanded ? "收起简介" : "展开简介",
            isExpanded: isExpanded
          ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
              isExpanded.toggle()
            }
          }
        }
      }
    }
  }
}

private struct SubjectInfoGridCard: View {
  let subject: BangumiSubject

  var body: some View {
    let items = metadataItems

    if !items.isEmpty {
      SubjectSectionCard(title: "信息") {
        VStack(spacing: 10) {
          ForEach(items, id: \.title) { item in
            SubjectInfoTile(title: item.title, value: item.value, systemImage: item.systemImage)
          }
        }
      }
    }
  }

  private var metadataItems: [(title: String, value: String, systemImage: String)] {
    var items: [(String, String, String)] = []

    if let date = subject.date, !date.isEmpty {
      items.append((dateTitle, date, "calendar"))
    }
    if let totalEpisodes = subject.totalEpisodes ?? subject.eps, totalEpisodes > 0 {
      items.append(("章节数量", "\(totalEpisodes)", "play.square.stack"))
    }
    if let volumes = subject.volumes, volumes > 0 {
      items.append(("卷数", "\(volumes)", "books.vertical"))
    }
    if let platform = subject.platform, !platform.isEmpty {
      items.append(("平台", platform, "shippingbox"))
    }
    if subject.locked == true {
      items.append(("状态", "锁定", "lock"))
    }
    return items
  }

  private var dateTitle: String {
    guard let type = SubjectType(rawValue: subject.type ?? 0) else {
      return "日期"
    }

    switch type {
    case .anime:
      if let platform = subject.platform?.lowercased() {
        if platform.contains("剧场") || platform.contains("movie") || platform.contains("film") || platform.contains("电影") {
          return "上映日期"
        }
      }
      return "放送日期"
    case .book:
      return "出版日期"
    case .music:
      return "发售日期"
    case .game:
      return "发售日期"
    case .real:
      if let platform = subject.platform?.lowercased() {
        if platform.contains("电影") || platform.contains("movie") || platform.contains("film") {
          return "上映日期"
        }
      }
      return "首播日期"
    }
  }
}

private struct SubjectDisclosureButton: View {
  let title: String
  let isExpanded: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title)
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.caption.weight(.bold))
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
  }
}

private struct SubjectCollectionStatsCard: View {
  let stats: BangumiSubjectCollectionStats

  var body: some View {
    let items = [
      ("在看", stats.doing ?? 0),
      ("看过", stats.collect ?? 0),
      ("想看", stats.wish ?? 0),
      ("搁置", stats.onHold ?? 0),
      ("抛弃", stats.dropped ?? 0)
    ]
    .filter { $0.1 > 0 }

    if !items.isEmpty {
      SubjectSectionCard(title: "收藏概览") {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 88), spacing: 10)],
          spacing: 10
        ) {
          ForEach(items, id: \.0) { item in
            VStack(alignment: .leading, spacing: 6) {
              Text(item.0)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("\(item.1)")
                .font(.title3.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
    }
  }
}

private struct SubjectEpisodeProgressSection: View {
  let episodes: [BangumiEpisode]
  let statuses: [Int: BangumiEpisodeCollectionType]
  let watchedEpisodes: Int
  let isAuthenticated: Bool
  let updatingEpisodeID: Int?
  let onSelectStatus: (BangumiEpisode, BangumiEpisodeCollectionType) -> Void

  private let columns = [
    GridItem(.adaptive(minimum: 48, maximum: 58), spacing: 12, alignment: .top)
  ]

  var body: some View {
    SubjectSectionCard(title: "进度") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 5) {
            Text(isAuthenticated ? "已同步 \(watchedEpisodes) 集" : "游客模式下可浏览章节信息")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          SubjectProgressCountBadge(
            watchedEpisodes: watchedEpisodes,
            totalEpisodes: episodes.count
          )
        }

        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
          ForEach(episodes) { episode in
            SubjectEpisodeProgressTile(
              episode: episode,
              status: statuses[episode.id] ?? .none,
              isAuthenticated: isAuthenticated,
              isUpdating: updatingEpisodeID == episode.id,
              onSelectStatus: onSelectStatus
            )
          }
        }
      }
    }
  }
}

private struct SubjectEpisodeProgressTile: View {
  let episode: BangumiEpisode
  let status: BangumiEpisodeCollectionType
  let isAuthenticated: Bool
  let isUpdating: Bool
  let onSelectStatus: (BangumiEpisode, BangumiEpisodeCollectionType) -> Void

  var body: some View {
    Menu {
      SubjectEpisodeActionMenuContent(
        episode: episode,
        currentStatus: status,
        isAuthenticated: isAuthenticated,
        isUpdating: isUpdating,
        onSelectStatus: { nextStatus in
          onSelectStatus(episode, nextStatus)
        }
      )
    } label: {
      VStack(spacing: 0) {
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tileFill)
          Text(tileLabel)
            .font(.system(size: tileLabel.count > 3 ? 16 : 20, weight: .bold, design: .rounded))
            .foregroundStyle(tileForeground)
            .minimumScaleFactor(0.72)
          if isUpdating {
            ProgressView()
              .tint(tileForeground)
          }
        }
        .frame(height: 52)

        RoundedRectangle(cornerRadius: 999, style: .continuous)
          .fill(indicatorFill)
          .frame(height: 5)
          .padding(.horizontal, 4)
          .padding(.top, 6)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isUpdating)
    .accessibilityLabel("\(episode.nameCN ?? episode.name ?? "未知章节")，\(status.title)")
    .accessibilityHint("展开章节操作")
  }

  private var tileLabel: String {
    guard let sort = episode.sort else { return "?" }
    if sort.rounded(.towardZero) == sort {
      return "\(Int(sort))"
    }
    return sort.formatted(.number.precision(.fractionLength(1)))
  }

  private var tileFill: Color {
    switch status {
    case .watched:
      return Color.accentColor
    case .wish:
      return Color.accentColor.opacity(0.18)
    case .dropped:
      return Color(uiColor: .systemGray5)
    case .none:
      return Color(uiColor: .secondarySystemGroupedBackground)
    }
  }

  private var tileForeground: Color {
    switch status {
    case .watched:
      return .white
    case .wish:
      return .accentColor
    case .dropped:
      return Color(uiColor: .secondaryLabel)
    case .none:
      return .primary
    }
  }

  private var indicatorFill: Color {
    switch status {
    case .watched:
      return Color.orange.opacity(0.72)
    case .wish:
      return Color.accentColor.opacity(0.55)
    case .dropped:
      return Color(uiColor: .systemGray3)
    case .none:
      return Color(uiColor: .systemGray5)
    }
  }
}

private struct SubjectEpisodeActionMenuContent: View {
  let episode: BangumiEpisode
  let currentStatus: BangumiEpisodeCollectionType
  let isAuthenticated: Bool
  let isUpdating: Bool
  let onSelectStatus: (BangumiEpisodeCollectionType) -> Void

  var body: some View {
    Group {
      Button(episodeDisplayLabel) {}
        .disabled(true)

      if let localizedName = episode.nameCN ?? episode.name, !localizedName.isEmpty {
        Button(localizedName) {}
          .disabled(true)
      }

      if let originalName = episode.name,
         let localizedName = episode.nameCN,
         originalName != localizedName {
        Button(originalName) {}
          .disabled(true)
      }

      if let airdate = episode.airdate, !airdate.isEmpty {
        Button(airdate) {}
          .disabled(true)
      }

      Divider()

      if isAuthenticated {
        ForEach([
          BangumiEpisodeCollectionType.watched,
          .wish,
          .dropped,
          .none
        ], id: \.self) { status in
          Button {
            onSelectStatus(status)
          } label: {
            if currentStatus == status {
              Label(status == .none ? "撤销" : status.title, systemImage: "checkmark")
            } else {
              Text(status == .none ? "撤销" : status.title)
            }
          }
          .disabled(isUpdating)
        }
      } else {
        Button("登录后可同步这一集的状态。") {}
          .disabled(true)
      }
    }
  }

  private var episodeDisplayLabel: String {
    guard let sort = episode.sort else { return "EP ?" }
    if sort.rounded(.towardZero) == sort {
      return "EP \(Int(sort))"
    }
    return "EP \(sort.formatted(.number.precision(.fractionLength(1))))"
  }
}

private struct SubjectCommentsSection: View {
  let comments: [BangumiSubjectComment]
  let isLoading: Bool
  let errorMessage: String?
  let moreURL: URL?

  @EnvironmentObject private var model: BangumiAppModel

  var body: some View {
    SubjectPlainSection(
      title: "吐槽",
      actionTitle: moreURL == nil ? nil : "更多吐槽",
      action: moreURL.map { url in { model.present(url: url) } }
    ) {
      VStack(alignment: .leading, spacing: 0) {
        if isLoading && comments.isEmpty {
          ProgressView("正在读取吐槽...")
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if comments.isEmpty {
          Text(errorMessage ?? "暂时没有读取到公开吐槽。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(comments) { comment in
            SubjectCommentRow(comment: comment)
            if comment.id != (comments.last?.id ?? "") {
              Divider()
                .padding(.leading, 64)
                .padding(.vertical, 18)
            }
          }
        }

        if let errorMessage, !errorMessage.isEmpty, !comments.isEmpty {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
        }
      }
    }
  }
}

private struct SubjectCommentRow: View {
  let comment: BangumiSubjectComment

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CoverImage(url: comment.avatarURL)
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          UserNameButton(
            title: comment.userName,
            userID: comment.userID,
            font: .system(size: 19, weight: .bold)
          )
          .lineLimit(1)

          Spacer(minLength: 0)
        }

        if !metaLine.isEmpty {
          Text(metaLine)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(comment.message)
          .font(.system(size: 16, weight: .regular))
          .foregroundStyle(.primary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 1)
    }
  }

  private var metaLine: String {
    var parts: [String] = []

    if let userSign = comment.userSign?.trimmingCharacters(in: .whitespacesAndNewlines),
       !userSign.isEmpty {
      parts.append(userSign)
    }

    let time = localizedTime(comment.time)
    if !time.isEmpty {
      parts.append(time)
    }

    return parts.joined(separator: " · ")
  }

  private func localizedTime(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.localizedCaseInsensitiveContains("ago") else { return trimmed }

    var localized = trimmed
      .replacingOccurrences(of: " ago", with: "前")
      .replacingOccurrences(of: "h ", with: "小时")
      .replacingOccurrences(of: "m ", with: "分钟")
      .replacingOccurrences(of: "d ", with: "天")
      .replacingOccurrences(of: "h", with: "小时")
      .replacingOccurrences(of: "m", with: "分钟")
      .replacingOccurrences(of: "d", with: "天")
      .replacingOccurrences(of: "Just now", with: "刚刚")

    localized = localized
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return localized
  }
}

private struct SubjectSectionCard<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.title3.weight(.bold))
        .foregroundStyle(.primary)

      content
    }
    .bangumiCardStyle()
  }
}

private struct SubjectInlineMessageCard: View {
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(.orange)
      Text(message)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct SubjectCollectionSummaryChip: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
  }
}

private struct SubjectProgressCountBadge: View {
  let watchedEpisodes: Int
  let totalEpisodes: Int

  var body: some View {
    VStack(alignment: .trailing, spacing: 3) {
      Text(totalEpisodes > 0 ? "\(watchedEpisodes) / \(totalEpisodes)" : "\(watchedEpisodes)")
        .font(.system(size: 21, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      Text("已标记")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct SubjectCapsuleLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.black.opacity(0.82))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.white.opacity(0.86), in: Capsule())
  }
}

private struct SubjectHeroBadge: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.black.opacity(0.55), in: Capsule())
  }
}

private struct SubjectMetricTile: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.footnote.weight(.semibold))
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct SubjectInfoTile: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage)
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      Spacer(minLength: 16)

      Text(value)
        .font(.system(.body, design: .default, weight: .semibold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: 320, minHeight: 46, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct SubjectTagChip: View {
  let tag: BangumiTag

  var body: some View {
    HStack(spacing: 6) {
      Text(tag.name)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.84)
        .layoutPriority(1)
      if let count = tag.count {
        Text("\(count)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private final class SubjectDetailViewModel: ObservableObject {
  @Published var subject: BangumiSubject?
  @Published var presentation: BangumiSubjectPresentation = .empty
  @Published var episodes: [BangumiEpisode] = []
  @Published var collection: BangumiSubjectCollectionRecord?
  @Published var episodeStatuses: [Int: BangumiEpisodeCollectionType] = [:]
  @Published var comments: [BangumiSubjectComment] = []
  @Published var watchedEpisodes = 0
  @Published var isLoading = false
  @Published var isLoadingComments = false
  @Published var isLoadingPresentation = false
  @Published var updatingEpisodeID: Int?
  @Published var errorMessage: String?
  @Published var commentsErrorMessage: String?

  var navigationTitle: String {
    if let subject {
      return subject.nameCN ?? subject.name
    }
    return "条目详情"
  }

  var editorPayload: CollectionUpdatePayload {
    CollectionUpdatePayload(
      status: statusFromCollection(collection),
      rating: collection?.rate ?? 0,
      tags: collection?.tags?.joined(separator: " ") ?? "",
      comment: collection?.comment ?? "",
      isPrivate: false,
      watchedEpisodes: collection?.epStatus ?? 0,
      watchedVolumes: collection?.volStatus ?? 0
    )
  }

  @MainActor
  func load(subjectID: Int, repository: SubjectRepository, isAuthenticated: Bool) async {
    isLoading = true
    isLoadingComments = true
    isLoadingPresentation = true
    errorMessage = nil
    commentsErrorMessage = nil
    presentation = .empty
    defer { isLoading = false }

    do {
      async let subjectTask = repository.fetchSubject(id: subjectID)
      async let episodesResult: Result<[BangumiEpisode], Error> = loadResult {
        try await repository.fetchEpisodes(subjectID: subjectID)
      }
      async let commentsResult: Result<[BangumiSubjectComment], Error> = loadResult {
        try await repository.fetchSubjectComments(subjectID: subjectID)
      }
      async let presentationResult: Result<BangumiSubjectPresentation, Error> = loadResult {
        try await repository.fetchSubjectPresentation(subjectID: subjectID)
      }
      async let collectionResult: Result<BangumiSubjectCollectionRecord?, Error> = loadOptionalResult {
        guard isAuthenticated else { return nil }
        return try await repository.fetchCollection(subjectID: subjectID)
      }
      async let episodeCollectionsResult: Result<[BangumiEpisodeCollection], Error> = loadResult {
        guard isAuthenticated else { return [BangumiEpisodeCollection]() }
        return try await repository.fetchEpisodeCollections(subjectID: subjectID)
      }

      let loadedSubject = try await subjectTask
      subject = loadedSubject

      let resolvedEpisodesResult = await episodesResult
      let resolvedEpisodes: [BangumiEpisode]
      switch resolvedEpisodesResult {
      case let .success(loadedEpisodes):
        resolvedEpisodes = loadedEpisodes
        episodes = loadedEpisodes
      case let .failure(error):
        resolvedEpisodes = []
        episodes = []
        errorMessage = "章节信息加载不完整：\(error.localizedDescription)"
      }

      let resolvedCommentsResult = await commentsResult
      switch resolvedCommentsResult {
      case let .success(loadedComments):
        comments = loadedComments
        commentsErrorMessage = nil
      case let .failure(error):
        comments = []
        commentsErrorMessage = "吐槽加载失败：\(error.localizedDescription)"
      }
      isLoadingComments = false

      switch await presentationResult {
      case let .success(loadedPresentation):
        presentation = loadedPresentation
      case .failure:
        presentation = .empty
      }
      isLoadingPresentation = false

      let resolvedCollectionResult = await collectionResult
      let resolvedCollection: BangumiSubjectCollectionRecord?
      switch resolvedCollectionResult {
      case let .success(loadedCollection):
        resolvedCollection = loadedCollection
      case .failure:
        resolvedCollection = nil
      }
      collection = resolvedCollection

      let resolvedEpisodeCollections: [BangumiEpisodeCollection]
      switch await episodeCollectionsResult {
      case let .success(collections):
        resolvedEpisodeCollections = collections
      case .failure:
        resolvedEpisodeCollections = []
        if loadedSubject.type == SubjectType.anime.rawValue && errorMessage == nil {
          errorMessage = "逐集进度暂时无法同步，已先显示基础信息。"
        }
      }

      episodeStatuses = mergedEpisodeStatuses(
        episodes: resolvedEpisodes,
        explicitCollections: resolvedEpisodeCollections,
        fallbackWatchedEpisodes: resolvedCollection?.epStatus ?? 0
      )
      watchedEpisodes = resolvedCollection?.epStatus ?? countedWatchedEpisodes(from: episodeStatuses)
      if !episodeStatuses.isEmpty {
        watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
      }

      let shouldHintEpisodeFallback =
        loadedSubject.type == SubjectType.anime.rawValue &&
        max(loadedSubject.eps ?? 0, loadedSubject.totalEpisodes ?? 0) > 0 &&
        resolvedEpisodes.isEmpty

      if shouldHintEpisodeFallback {
        errorMessage = "章节列表暂时不可用，条目基础信息已加载。"
      }
    } catch {
      errorMessage = error.localizedDescription
      presentation = .empty
      isLoadingComments = false
      isLoadingPresentation = false
    }
  }

  @MainActor
  func saveCollection(using repository: SubjectRepository, subjectID: Int, payload: CollectionUpdatePayload) async {
    do {
      try await repository.updateCollection(subjectID: subjectID, payload: payload)
      if payload.watchedEpisodes != nil || payload.watchedVolumes != nil {
        try await repository.updateWatchedProgress(
          subjectID: subjectID,
          watchedEpisodes: payload.watchedEpisodes,
          watchedVolumes: payload.watchedVolumes
        )
      }
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      errorMessage = nil
    } catch {
      errorMessage = "收藏保存失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  func saveProgress(using repository: SubjectRepository, subjectID: Int) async {
    do {
      try await repository.updateWatchedProgress(subjectID: subjectID, watchedEpisodes: watchedEpisodes)
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      errorMessage = nil
    } catch {
      errorMessage = "进度更新失败：\(error.localizedDescription)"
    }
  }

  @MainActor
  func markEpisodeWatched(using repository: SubjectRepository, episodeID: Int) async {
    do {
      try await repository.markEpisodeWatched(episodeID: episodeID)
      episodeStatuses[episodeID] = .watched
      watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
      errorMessage = nil
    } catch {
      errorMessage = "章节状态更新失败：\(error.localizedDescription)"
    }
  }

  func status(for episode: BangumiEpisode) -> BangumiEpisodeCollectionType {
    episodeStatuses[episode.id] ?? .none
  }

  @MainActor
  func updateEpisodeStatus(
    using repository: SubjectRepository,
    subjectID: Int,
    episode: BangumiEpisode,
    status: BangumiEpisodeCollectionType,
    isAuthenticated: Bool
  ) async -> Bool {
    guard isAuthenticated else {
      errorMessage = "登录后才可以同步逐集进度。"
      return false
    }

    let previousStatus = episodeStatuses[episode.id] ?? .none
    updatingEpisodeID = episode.id
    applyEpisodeStatus(status, for: episode.id)
    errorMessage = nil

    do {
      try await repository.updateEpisodeCollection(episodeID: episode.id, type: status)
      collection = try? await repository.fetchCollection(subjectID: subjectID)
      updatingEpisodeID = nil
      return true
    } catch {
      applyEpisodeStatus(previousStatus, for: episode.id)
      errorMessage = "章节状态更新失败：\(error.localizedDescription)"
      updatingEpisodeID = nil
      return false
    }
  }

  func collectionTitle(from collection: BangumiSubjectCollectionRecord) -> String {
    guard let type = collection.type else { return "未收藏" }
    return Self.statusTitle(for: type)
  }

  private func statusFromCollection(_ collection: BangumiSubjectCollectionRecord?) -> CollectionStatus {
    guard let type = collection?.type else { return CollectionStatus.doing }
    switch type {
    case "1", "wish": return CollectionStatus.wish
    case "2", "collect": return CollectionStatus.collect
    case "4", "on_hold": return CollectionStatus.onHold
    case "5", "dropped": return CollectionStatus.dropped
    default: return CollectionStatus.doing
    }
  }

  private static func statusTitle(for raw: String) -> String {
    switch raw {
    case "1", "wish": "想看"
    case "2", "collect": "看过"
    case "4", "on_hold": "搁置"
    case "5", "dropped": "抛弃"
    default: "在看"
    }
  }

  private func applyEpisodeStatus(_ status: BangumiEpisodeCollectionType, for episodeID: Int) {
    if status == .none {
      episodeStatuses.removeValue(forKey: episodeID)
    } else {
      episodeStatuses[episodeID] = status
    }
    watchedEpisodes = countedWatchedEpisodes(from: episodeStatuses)
  }

  private func mergedEpisodeStatuses(
    episodes: [BangumiEpisode],
    explicitCollections: [BangumiEpisodeCollection],
    fallbackWatchedEpisodes: Int
  ) -> [Int: BangumiEpisodeCollectionType] {
    var merged = explicitCollections.reduce(into: [Int: BangumiEpisodeCollectionType]()) { partialResult, item in
      if item.type != .none {
        partialResult[item.episodeID] = item.type
      }
    }

    guard fallbackWatchedEpisodes > 0 else { return merged }

    for episode in episodes {
      guard merged[episode.id] == nil else { continue }
      if let sort = episode.sort, sort > 0, sort <= Double(fallbackWatchedEpisodes) {
        merged[episode.id] = .watched
      }
    }

    return merged
  }

  private func countedWatchedEpisodes(from statuses: [Int: BangumiEpisodeCollectionType]) -> Int {
    statuses.values.filter { $0 == .watched }.count
  }

  private func loadResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
    do {
      return .success(try await operation())
    } catch {
      return .failure(error)
    }
  }

  private func loadOptionalResult<T>(_ operation: @escaping () async throws -> T?) async -> Result<T?, Error> {
    do {
      return .success(try await operation())
    } catch {
      return .failure(error)
    }
  }
}

private struct CollectionEditorScreen: View {
  let title: String
  let subjectType: Int?
  let totalEpisodes: Int
  let totalVolumes: Int
  let initialPayload: CollectionUpdatePayload
  let onSave: (CollectionUpdatePayload) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var status: CollectionStatus
  @State private var rating: Int
  @State private var tags: String
  @State private var comment: String
  @State private var isPrivate: Bool
  @State private var watchedEpisodes: Int
  @State private var watchedVolumes: Int

  private var isBook: Bool {
    subjectType == SubjectType.book.rawValue
  }

  init(
    title: String,
    subjectType: Int?,
    totalEpisodes: Int,
    totalVolumes: Int,
    initialPayload: CollectionUpdatePayload,
    onSave: @escaping (CollectionUpdatePayload) -> Void
  ) {
    self.title = title
    self.subjectType = subjectType
    self.totalEpisodes = totalEpisodes
    self.totalVolumes = totalVolumes
    self.initialPayload = initialPayload
    self.onSave = onSave
    _status = State(initialValue: initialPayload.status)
    _rating = State(initialValue: initialPayload.rating)
    _tags = State(initialValue: initialPayload.tags)
    _comment = State(initialValue: initialPayload.comment)
    _isPrivate = State(initialValue: initialPayload.isPrivate)
    _watchedEpisodes = State(initialValue: initialPayload.watchedEpisodes ?? 0)
    _watchedVolumes = State(initialValue: initialPayload.watchedVolumes ?? 0)
  }

  var body: some View {
    Form {
      Section(title) {
        Picker("收藏状态", selection: $status) {
          ForEach(CollectionStatus.allCases) { status in
            Text(status.title).tag(status)
          }
        }

        Stepper("评分 \(rating)", value: $rating, in: 0 ... 10)

        if isBook, totalVolumes > 0 {
          Stepper(
            "已读卷数 \(watchedVolumes)/\(totalVolumes)",
            value: $watchedVolumes,
            in: 0 ... totalVolumes
          )
        } else if totalEpisodes > 0 {
          Stepper(
            "已看进度 \(watchedEpisodes)/\(totalEpisodes)",
            value: $watchedEpisodes,
            in: 0 ... totalEpisodes
          )
        }

        TextField("标签（空格分隔）", text: $tags)
        TextField("短评", text: $comment, axis: .vertical)
        Toggle("私密收藏", isOn: $isPrivate)
      }
    }
    .navigationTitle("编辑收藏")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("关闭") {
          dismiss()
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button("保存") {
          onSave(
            CollectionUpdatePayload(
              status: status,
              rating: rating,
              tags: tags,
              comment: comment,
              isPrivate: isPrivate,
              watchedEpisodes: isBook ? nil : watchedEpisodes,
              watchedVolumes: isBook ? watchedVolumes : nil
            )
          )
          dismiss()
        }
      }
    }
  }
}

private struct RakuenScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = RakuenViewModel()

  var body: some View {
    ScreenScaffold(
      title: "Rakuen",
      subtitle: "V1 先接入原生列表，主题详情暂保留 Web 回退。",
      navigationBarStyle: .discoveryNative
    ) {
      Group {
        if viewModel.isLoading && viewModel.items.isEmpty {
          ProgressView("加载中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
          UnavailableStateView(
            title: "Rakuen 加载失败",
            systemImage: "bubble.left.and.bubble.right",
            message: error
          )
        } else {
          List {
            Section {
              Picker("类型", selection: $viewModel.filter) {
                ForEach(RakuenFilter.allCases) { filter in
                  Text(filter.title).tag(filter)
                }
              }
              .pickerStyle(.segmented)
            }

            ForEach(viewModel.items) { item in
              NavigationLink {
                RakuenTopicScreen(topicURL: item.topicURL, fallbackTitle: item.title)
              } label: {
                RakuenRow(item: item)
              }
            }
          }
          .refreshable {
            await viewModel.refresh(using: model.rakuenRepository)
          }
          .bangumiRootScrollableLayout()
        }
      }
      .task {
        await viewModel.bootstrap(using: model.rakuenRepository)
      }
      .onChange(of: viewModel.filter) { _ in
        Task {
          await viewModel.refresh(using: model.rakuenRepository)
        }
      }
    }
  }
}

private final class RakuenViewModel: ObservableObject {
  @Published var items: [BangumiRakuenItem] = []
  @Published var filter: RakuenFilter = .all
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var hasBootstrapped = false

  @MainActor
  func bootstrap(using repository: RakuenRepository) async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    await refresh(using: repository)
  }

  @MainActor
  func refresh(using repository: RakuenRepository) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      items = try await repository.fetch(filter: filter)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct RakuenRow: View {
  let item: BangumiRakuenItem

  var body: some View {
    HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
      CoverImage(url: item.avatarURL)
        .frame(width: 42, height: 42)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
        Text(item.title)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(2)

        HStack(spacing: 8) {
          Text(item.userName)
          if let groupName = item.groupName, !groupName.isEmpty {
            Text(groupName)
          }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)

        HStack(spacing: BangumiDesign.sectionSpacing) {
          if !item.time.isEmpty {
            Label(item.time, systemImage: "clock")
          }
          if let replyCount = item.replyCount {
            Label(replyCount, systemImage: "text.bubble")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct RakuenTopicScreen: View {
  let topicURL: URL?
  let fallbackTitle: String

  @EnvironmentObject private var model: BangumiAppModel
  @StateObject private var viewModel = RakuenTopicViewModel()

  var body: some View {
    Group {
      if let topicURL {
        content(for: topicURL)
      } else {
        UnavailableStateView(
          title: fallbackTitle,
          systemImage: "bubble.left.and.bubble.right",
          message: "暂时没有可用的帖子地址。"
        )
      }
    }
    .task(id: topicURL?.absoluteString) {
      guard let topicURL else { return }
      await viewModel.load(using: model.rakuenRepository, url: topicURL)
    }
    .navigationTitle(viewModel.detail?.topic.title ?? fallbackTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let topicURL {
        ToolbarItem(placement: .topBarTrailing) {
          Link(destination: topicURL) {
            Label("在 Safari 中打开", systemImage: "safari")
              .labelStyle(.iconOnly)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func content(for topicURL: URL) -> some View {
    if viewModel.isLoading && viewModel.detail == nil {
      ProgressView("加载中...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = viewModel.errorMessage, viewModel.detail == nil {
      UnavailableStateView(
        title: fallbackTitle,
        systemImage: "exclamationmark.triangle",
        message: error
      )
    } else if let detail = viewModel.detail, viewModel.hasRenderableContent {
      List {
        Section("主楼") {
          RakuenPostCard(
            avatarURL: detail.topic.avatarURL,
            userName: detail.topic.userName,
            userID: detail.topic.userID,
            userSign: detail.topic.userSign,
            floor: detail.topic.floor,
            time: detail.topic.time,
            message: detail.topic.message,
            htmlMessage: detail.topic.htmlMessage
          )

          if let groupName = detail.topic.groupName, !groupName.isEmpty {
            LabeledContent("版块", value: groupName)
          }
        }

        if detail.comments.isEmpty {
          Section("回复") {
            Text("当前没有解析到回复，稍后可以点右上角 Safari 回退到网页。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        } else {
          Section("回复 \(detail.comments.count)") {
            ForEach(detail.comments) { comment in
              RakuenPostCard(
                avatarURL: comment.avatarURL,
                userName: comment.userName,
                userID: comment.userID,
                userSign: comment.userSign,
                floor: comment.floor,
                time: comment.time,
                message: comment.message,
                htmlMessage: comment.htmlMessage,
                subReplies: comment.subReplies
              )
            }
          }
        }
      }
      .refreshable {
        await viewModel.refresh(using: model.rakuenRepository, url: topicURL)
      }
    } else {
      UnavailableStateView(
        title: fallbackTitle,
        systemImage: "bubble.left.and.bubble.right",
        message: "暂时没有解析到帖子内容，可以先用右上角 Safari 查看原文。"
      )
    }
  }
}

private final class RakuenTopicViewModel: ObservableObject {
  @Published var detail: BangumiRakuenTopicDetail?
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var hasAttemptedLoad = false

  private var loadedURL: URL?

  var hasRenderableContent: Bool {
    guard let detail else { return false }
    let topicMessage = detail.topic.message.trimmingCharacters(in: .whitespacesAndNewlines)
    let topicHTML = detail.topic.htmlMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !topicMessage.isEmpty || !topicHTML.isEmpty || !detail.comments.isEmpty
  }

  @MainActor
  func load(using repository: RakuenRepository, url: URL) async {
    if loadedURL == url, detail != nil { return }
    await refresh(using: repository, url: url)
  }

  @MainActor
  func refresh(using repository: RakuenRepository, url: URL) async {
    isLoading = true
    hasAttemptedLoad = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      detail = try await repository.fetchTopic(url: url)
      loadedURL = url
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct RakuenPostCard: View {
  let avatarURL: URL?
  let userName: String
  var userID: String? = nil
  let userSign: String?
  let floor: String?
  let time: String
  let message: String
  var htmlMessage: String? = nil
  var subReplies: [BangumiRakuenSubReply] = []

  var body: some View {
    VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
      HStack(alignment: .top, spacing: BangumiDesign.rowSpacing) {
        CoverImage(url: avatarURL)
          .frame(width: 40, height: 40)
          .clipShape(Circle())
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          HStack(alignment: .firstTextBaseline, spacing: BangumiDesign.sectionSpacing) {
            UserNameButton(title: userName, userID: userID)

            if let floor, !floor.isEmpty {
              Text(floor)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if let userSign, !userSign.isEmpty {
            Text(userSign)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let htmlMessage, !htmlMessage.isEmpty {
            BangumiRichText(html: htmlMessage)
              .textSelection(.enabled)
          } else if !message.isEmpty {
            Text(message)
              .font(.body)
              .textSelection(.enabled)
          }

          if !time.isEmpty {
            Label(time, systemImage: "clock")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !subReplies.isEmpty {
        VStack(alignment: .leading, spacing: BangumiDesign.sectionSpacing) {
          ForEach(subReplies) { reply in
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline, spacing: BangumiDesign.sectionSpacing) {
                UserNameButton(title: reply.userName, userID: reply.userID, font: .subheadline)
                  .bold()

                if let floor = reply.floor, !floor.isEmpty {
                  Text(floor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              if let userSign = reply.userSign, !userSign.isEmpty {
                Text(userSign)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              if let htmlMessage = reply.htmlMessage, !htmlMessage.isEmpty {
                BangumiRichText(html: htmlMessage)
                  .font(.subheadline)
                  .textSelection(.enabled)
              } else {
                Text(reply.message)
                  .font(.subheadline)
                  .textSelection(.enabled)
              }

              if !reply.time.isEmpty {
                Label(reply.time, systemImage: "clock")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(BangumiDesign.cardPadding)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(.leading, 52)
      }
    }
    .bangumiCardStyle()
    .padding(.vertical, 4)
  }
}

private struct NotificationManagementScreen: View {
  var showsDismissButton = false

  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var notificationStore: BangumiNotificationStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: notificationStore.permissionState.systemImage)
              .font(.title2.weight(.semibold))
              .foregroundStyle(notificationStore.permissionState.canDeliverNotifications ? Color.orange : Color.secondary)
              .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
              Text(notificationStore.permissionState.title)
                .font(.headline)

              Text(notificationStore.permissionState.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
          }

          HStack(spacing: 12) {
            Button {
              Task {
                await notificationStore.performManualCheck()
              }
            } label: {
              HStack {
                if notificationStore.isCheckingUpdates {
                  ProgressView()
                    .controlSize(.small)
                } else {
                  Image(systemName: "arrow.clockwise")
                }
                Text(notificationStore.isCheckingUpdates ? "检查中..." : "立即检查更新")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(notificationStore.isCheckingUpdates)

            if notificationStore.permissionState == .denied {
              Button("去设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
              }
              .buttonStyle(.bordered)
            }
          }

          if let lastCheckedAt = notificationStore.lastCheckedAt {
            Text("最近检查：\(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let statusMessage = notificationStore.statusMessage, !statusMessage.isEmpty {
            Text(statusMessage)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .bangumiCardStyle()
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section("已订阅条目") {
        if notificationStore.subscriptions.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("还没有开启任何条目提醒。")
              .font(.headline)
            Text("去任意条目详情页开启“更新提醒”后，这里会集中管理全部订阅。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
        } else {
          ForEach(notificationStore.subscriptions) { subscription in
            HStack(alignment: .top, spacing: 12) {
              NavigationLink {
                SubjectDetailScreen(subjectID: subscription.subjectID)
              } label: {
                HStack(alignment: .top, spacing: 12) {
                  CoverImage(url: subscription.coverURL)
                    .frame(width: 52, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                  VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                      Text(subscription.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                      if let subjectTypeTitle = subscription.subjectTypeTitle, !subjectTypeTitle.isEmpty {
                        Text(subjectTypeTitle)
                          .font(.caption.weight(.semibold))
                          .foregroundStyle(.secondary)
                          .padding(.horizontal, 8)
                          .padding(.vertical, 4)
                          .background(Color.secondary.opacity(0.12), in: Capsule())
                      }
                    }

                    if let subtitle = subscription.subtitle, !subtitle.isEmpty {
                      Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Text("当前基线：\(subscription.latestEpisodeLabel)")
                      .font(.caption)
                      .foregroundStyle(.secondary)

                    if let lastCheckedAt = subscription.lastCheckedAt {
                      Text("最近检查：\(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if let lastErrorMessage = subscription.lastErrorMessage, !lastErrorMessage.isEmpty {
                      Text(lastErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    }
                  }
                }
              }
              .buttonStyle(.plain)

              Spacer(minLength: 8)

              Toggle(
                "",
                isOn: Binding(
                  get: { notificationStore.subscription(for: subscription.subjectID) != nil },
                  set: { isOn in
                    if !isOn {
                      Task { @MainActor in
                        notificationStore.disableSubscription(subjectID: subscription.subjectID)
                      }
                    }
                  }
                )
              )
              .labelsHidden()
            }
            .padding(.vertical, 4)
          }
        }
      }

      if !notificationStore.subscriptions.isEmpty {
        Section {
          Button("全部关闭提醒", role: .destructive) {
            notificationStore.disableAllSubscriptions()
          }
        }
      }

      Section("Bangumi") {
        Button("打开站内通知网页") {
          model.presentedRoute = .web(URL(string: "https://bgm.tv/notify")!, "Bangumi 通知")
        }
      }
    }
    .navigationTitle("通知管理")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showsDismissButton {
        ToolbarItem(placement: .topBarLeading) {
          Button("关闭") {
            dismiss()
          }
        }
      }
    }
    .bangumiRootScrollableLayout()
  }
}

private struct LoginScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @Environment(\.dismiss) private var dismiss
  private let oauthWebDataStore = BangumiOAuthWebDataStore()
  @State private var manualToken = ""
  @State private var isLoading = false
  @State private var isShowingOAuthWebLogin = false
  @State private var isShowingOAuthWebDataDialog = false
  @State private var isClearingOAuthWebData = false
  @State private var oauthAuthorization: BangumiOAuthAuthorizationSession?
  @State private var oauthWebDataMessage: String?
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("OAuth") {
        Text("Bangumi 当前应用注册的是网页回调地址，这里改成和原版一致的网页登录流程。登录并授权后会自动回到应用内完成登录。")
          .font(.footnote)
          .foregroundStyle(.secondary)

        Button(isLoading ? "登录中..." : "开始网页登录") {
          errorMessage = nil
          oauthWebDataMessage = nil
          oauthAuthorization = model.apiClient.beginOAuthAuthorization()
          isShowingOAuthWebLogin = true
        }
        .disabled(isLoading)

        Button(isClearingOAuthWebData ? "正在清理..." : "清除 Bangumi 登录数据", role: .destructive) {
          isShowingOAuthWebDataDialog = true
        }
        .disabled(isLoading || isClearingOAuthWebData)

        if let oauthWebDataMessage {
          Text(oauthWebDataMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Section("手动 Token") {
        TextField("粘贴 Access Token", text: $manualToken)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        Button("使用 Token 登录") {
          Task {
            await signInWithToken()
          }
        }
        .disabled(isLoading || manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if let errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("登录")
    .confirmationDialog(
      "清除 Bangumi 登录数据？",
      isPresented: $isShowingOAuthWebDataDialog,
      titleVisibility: .visible
    ) {
      Button("清除", role: .destructive) {
        Task {
          await clearOAuthWebData()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("这会移除 Bangumi 网页登录的 Cookie 与站点数据，下次网页登录将使用新的网页会话。")
    }
    .navigationDestination(isPresented: $isShowingOAuthWebLogin) {
      if let oauthAuthorization {
        OAuthLoginScreen(
          authorization: oauthAuthorization,
          apiClient: model.apiClient,
          onCode: { code in
            isShowingOAuthWebLogin = false
            self.oauthAuthorization = nil
            Task {
              await signInWithOAuthCode(code)
            }
          },
          onFailure: { message in
            isShowingOAuthWebLogin = false
            self.oauthAuthorization = nil
            errorMessage = message
          }
        )
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("关闭") {
          dismiss()
        }
      }
    }
  }

  @MainActor
  private func signInWithOAuthCode(_ code: String) async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await model.authService.signInWithAuthorizationCode(code)
      errorMessage = nil
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func signInWithToken() async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await model.authService.signInWithToken(manualToken)
      errorMessage = nil
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func clearOAuthWebData() async {
    isClearingOAuthWebData = true
    defer { isClearingOAuthWebData = false }

    await oauthWebDataStore.clearBangumiOAuthWebsiteData()
    oauthWebDataMessage = "已清除 Bangumi 网页登录数据，下次网页登录会使用新的网页会话。"
  }
}

private struct OAuthLoginScreen: View {
  let apiClient: BangumiAPIClient
  let onCode: @MainActor (String) -> Void
  let onFailure: @MainActor (String) -> Void

  private let oauthWebDataStore = BangumiOAuthWebDataStore()
  @State private var authorization: BangumiOAuthAuthorizationSession
  @State private var reloadToken = UUID()
  @State private var isShowingOAuthWebDataDialog = false
  @State private var isClearingOAuthWebData = false
  @State private var oauthWebDataMessage: String?

  init(
    authorization: BangumiOAuthAuthorizationSession,
    apiClient: BangumiAPIClient,
    onCode: @escaping @MainActor (String) -> Void,
    onFailure: @escaping @MainActor (String) -> Void
  ) {
    self.apiClient = apiClient
    self.onCode = onCode
    self.onFailure = onFailure
    _authorization = State(initialValue: authorization)
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("登录 Bangumi 并在授权页点“授权”，应用会在检测到回调地址后自动完成登录。")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()

      if let oauthWebDataMessage {
        Text(oauthWebDataMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.bottom, 8)
      }

      BangumiOAuthWebView(
        authorization: authorization,
        reloadToken: reloadToken,
        apiClient: apiClient,
        onCode: onCode,
        onFailure: onFailure
      )
    }
    .navigationTitle("网页登录")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "清除 Bangumi 登录数据并重新加载？",
      isPresented: $isShowingOAuthWebDataDialog,
      titleVisibility: .visible
    ) {
      Button("清除并重新加载", role: .destructive) {
        Task {
          await clearOAuthWebDataAndReload()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("这会移除 Bangumi 网页登录的 Cookie 与站点数据，并重新载入新的授权页面。")
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("取消") {
          apiClient.cancelOAuthAuthorization()
          onFailure(BangumiError.oauthCancelled.localizedDescription)
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button(
            isClearingOAuthWebData ? "正在清理..." : "清除并重新加载",
            role: .destructive
          ) {
            isShowingOAuthWebDataDialog = true
          }
          .disabled(isClearingOAuthWebData)
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }

  @MainActor
  private func clearOAuthWebDataAndReload() async {
    isClearingOAuthWebData = true
    defer { isClearingOAuthWebData = false }

    await oauthWebDataStore.clearBangumiOAuthWebsiteData()
    apiClient.cancelOAuthAuthorization()
    authorization = apiClient.beginOAuthAuthorization()
    reloadToken = UUID()
    oauthWebDataMessage = "已清除 Bangumi 网页登录数据，并重新载入授权页。"
  }
}

private struct WebFallbackScreen: View {
  let title: String
  let subtitle: String?
  let url: URL?

  var body: some View {
    VStack(spacing: 0) {
      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
      }

      if let url {
        BangumiWebView(url: url)
      } else {
        UnavailableStateView(
          title: "地址不可用",
          systemImage: "safari",
          message: "请稍后再试。"
        )
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct UnavailableStateView: View {
  let title: String
  let systemImage: String
  let message: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

private struct BangumiWebView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if webView.url != url {
      webView.load(URLRequest(url: url))
    }
  }
}

private struct BangumiOAuthWebView: UIViewRepresentable {
  let authorization: BangumiOAuthAuthorizationSession
  let reloadToken: UUID
  let apiClient: BangumiAPIClient
  let onCode: @MainActor (String) -> Void
  let onFailure: @MainActor (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    configuration.websiteDataStore = .default()

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.load(URLRequest(url: authorization.authorizeURL))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self

    if context.coordinator.prepareForReloadIfNeeded(reloadToken) || webView.url == nil {
      webView.load(URLRequest(url: authorization.authorizeURL))
    }
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var parent: BangumiOAuthWebView
    private var hasHandledCallback = false
    private var hasRecoveredAuthorizeURL = false
    private var reloadToken: UUID

    init(_ parent: BangumiOAuthWebView) {
      self.parent = parent
      reloadToken = parent.reloadToken
    }

    func prepareForReloadIfNeeded(_ token: UUID) -> Bool {
      guard token != reloadToken else { return false }
      reloadToken = token
      hasHandledCallback = false
      hasRecoveredAuthorizeURL = false
      return true
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }

      if shouldRecoverAuthorizeURL(url) {
        decisionHandler(.cancel)
        recoverAuthorizeURL(in: webView)
        return
      }

      guard isOAuthCallback(url) else {
        decisionHandler(.allow)
        return
      }

      decisionHandler(.cancel)
      handleOAuthCallback(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let url = webView.url else { return }

      if shouldRecoverAuthorizeURL(url) {
        recoverAuthorizeURL(in: webView)
        return
      }

      if isOAuthCallback(url) {
        handleOAuthCallback(url)
      }
    }

    private func isOAuthCallback(_ url: URL) -> Bool {
      url.host?.lowercased() == parent.authorization.callbackURL.host?.lowercased()
        && url.path == parent.authorization.callbackURL.path
    }

    private func shouldRecoverAuthorizeURL(_ url: URL) -> Bool {
      guard !hasRecoveredAuthorizeURL else { return false }
      guard url.host?.lowercased() == parent.authorization.authorizeURL.host?.lowercased() else { return false }
      guard url.path == parent.authorization.authorizeURL.path else { return false }

      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let hasRedirectURI = components?.queryItems?.contains(where: { $0.name == "redirect_uri" }) ?? false
      return !hasRedirectURI
    }

    private func recoverAuthorizeURL(in webView: WKWebView) {
      guard !hasRecoveredAuthorizeURL else { return }
      hasRecoveredAuthorizeURL = true
      webView.load(URLRequest(url: parent.authorization.authorizeURL))
    }

    private func handleOAuthCallback(_ url: URL) {
      guard !hasHandledCallback else { return }

      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if let errorMessage = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
        ?? components?.queryItems?.first(where: { $0.name == "error" })?.value {
        hasHandledCallback = true
        parent.apiClient.cancelOAuthAuthorization()
        Task { @MainActor in
          parent.onFailure(errorMessage)
        }
        return
      }

      do {
        let code = try parent.apiClient.consumeOAuthCallback(url)
        hasHandledCallback = true
        Task { @MainActor in
          parent.onCode(code)
        }
      } catch {
        hasHandledCallback = true
        Task { @MainActor in
          parent.onFailure(error.localizedDescription)
        }
      }
    }
  }
}

private struct SubjectRow: View {
  let item: BangumiSubjectSummary

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      CoverImage(url: item.images?.best)
        .frame(width: 56, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 6) {
        Text(item.nameCN ?? item.name)
          .font(.headline)
          .foregroundStyle(.primary)

        if let nameCN = item.nameCN, nameCN != item.name {
          Text(item.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 12) {
          if let score = item.rating?.score {
            Text("评分 \(score, specifier: "%.1f")")
          }
          if let totalEpisodes = item.totalEpisodes ?? item.eps {
            Text("\(totalEpisodes) 集")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct CoverImage: View {
  let url: URL?

  var body: some View {
    BangumiRemoteImage(url: url) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.secondary.opacity(0.15))
        Image(systemName: "photo")
          .foregroundStyle(.secondary)
      }
    }
    .scaledToFill()
  }
}
