import SwiftUI

struct MeScreen: View {
  @EnvironmentObject private var model: BangumiAppModel
  @EnvironmentObject private var sessionStore: BangumiSessionStore
  @EnvironmentObject private var settingsStore: BangumiSettingsStore
  @StateObject private var viewModel = MeViewModel()
  @State private var headerOffset: CGFloat = 0
  @State private var isShowingLogoutConfirmation = false

  private let collapseThreshold: CGFloat = 220

  private var collapseProgress: CGFloat {
    min(max(-headerOffset / collapseThreshold, 0), 1)
  }

  private var shouldShowCompactHeader: Bool {
    collapseProgress > 0.62
  }

  var body: some View {
    Group {
      if let user = viewModel.currentUser, sessionStore.isAuthenticated {
        authenticatedContent(for: user)
      } else {
        guestContent
      }
    }
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .confirmationDialog(
      "退出当前账号？",
      isPresented: $isShowingLogoutConfirmation,
      titleVisibility: .visible
    ) {
      Button("退出登录", role: .destructive) {
        sessionStore.signOut()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("本地登录状态会被清除，但不会自动移除 Bangumi 网页登录数据。")
    }
    .task(id: sessionStore.currentUser?.id) {
      await viewModel.bootstrap(using: model.userRepository, sessionStore: sessionStore)
    }
  }

  private func authenticatedContent(for user: BangumiUser) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        GeometryReader { geometry in
          Color.clear
            .preference(
              key: MeScrollOffsetPreferenceKey.self,
              value: geometry.frame(in: .named("me-scroll")).minY
            )
        }
        .frame(height: 0)

        MeHeaderView(
          user: user,
          collapseProgress: collapseProgress,
          backgroundURL: user.avatar?.best,
          onProfileTap: openProfile
        )

        VStack(alignment: .leading, spacing: 18) {
          MeStatusTabs(
            summaries: viewModel.summaries,
            selectedStatus: viewModel.selectedStatus,
            isCompact: false
          ) { status in
            Task {
              await viewModel.selectStatus(status, using: model.userRepository)
            }
          }

          MeToolbar(
            sortOrder: viewModel.sortOrder,
            selectedTag: viewModel.selectedTag,
            availableTags: viewModel.availableTags,
            onSortSelect: { viewModel.sortOrder = $0 },
            onTagSelect: { viewModel.selectedTag = $0 },
            onRefresh: {
              Task {
                await viewModel.refresh(using: model.userRepository, sessionStore: sessionStore)
              }
            },
            onNotifications: { model.isShowingNotifications = true },
            onClearCache: { model.apiClient.clearCaches() },
            onProfile: openProfile,
            onLogout: { isShowingLogoutConfirmation = true }
          )

          if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
            Text(errorMessage)
              .font(.footnote)
              .foregroundStyle(.red)
              .padding(.horizontal, 16)
          }

          MeCollectionList(
            status: viewModel.selectedStatus,
            items: viewModel.selectedItems,
            isLoading: viewModel.isLoadingSelectedStatus,
            canLoadMore: viewModel.canLoadMoreSelectedStatus,
            errorMessage: viewModel.errorMessage
          ) {
            Task {
              await viewModel.loadMore(using: model.userRepository)
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 28)
        }
        .padding(.top, 18)
        .padding(.bottom, BangumiDesign.rootTabBarClearance)
        .background(
          Color(uiColor: .systemGroupedBackground),
          in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .offset(y: -30)
      }
    }
    .coordinateSpace(name: "me-scroll")
    .onPreferenceChange(MeScrollOffsetPreferenceKey.self) { headerOffset = $0 }
    .safeAreaInset(edge: .top, spacing: 0) {
      if shouldShowCompactHeader {
        VStack(spacing: 8) {
          HStack(spacing: 10) {
            BangumiRemoteImage(url: user.avatar?.best) {
              Circle().fill(Color.secondary.opacity(0.16))
            }
            .scaledToFill()
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
              Text(user.displayName)
                .font(.headline.weight(.bold))
              Text("@\(user.username)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)

          MeStatusTabs(
            summaries: viewModel.summaries,
            selectedStatus: viewModel.selectedStatus,
            isCompact: true
          ) { status in
            Task {
              await viewModel.selectStatus(status, using: model.userRepository)
            }
          }
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
      }
    }
    .refreshable {
      await viewModel.refresh(using: model.userRepository, sessionStore: sessionStore)
    }
    .searchable(
      text: $viewModel.searchText,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "搜索当前收藏"
    )
  }

  private var guestContent: some View {
    ScrollView {
      VStack(spacing: 22) {
        ZStack(alignment: .bottomLeading) {
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.88),
              Color.orange.opacity(0.68),
              Color.pink.opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          VStack(alignment: .leading, spacing: 12) {
            Text("我的")
              .font(.system(size: 42, weight: .heavy, design: .rounded))
              .foregroundStyle(.white)

            Text("登录后把想看、看过、在看、搁置和抛弃的动画收藏集中管理。")
              .font(.body)
              .foregroundStyle(.white.opacity(0.88))

            Button("登录 Bangumi") {
              model.isShowingLogin = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color.accentColor)
        }
          .padding(24)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)

        VStack(alignment: .leading, spacing: 14) {
          Text("登录后可用")
            .font(.title3.weight(.bold))

          ForEach([
            "沉浸式个人页头图与头像信息",
            "五状态收藏切换与搜索筛选",
            "按收藏时间、评分、放送日期排序",
            "通知、主题、缓存与账号管理"
          ], id: \.self) { item in
            Label(item, systemImage: "checkmark.circle.fill")
              .foregroundStyle(.primary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)

        Spacer(minLength: BangumiDesign.rootTabBarClearance)
      }
      .padding(.bottom, BangumiDesign.rootTabBarClearance)
    }
  }

  private func openProfile() {
    guard let username = sessionStore.currentUser?.username, !username.isEmpty else { return }
    model.presentedRoute = .user(username)
  }
}

private struct MeScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
