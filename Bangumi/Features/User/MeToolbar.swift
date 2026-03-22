import SwiftUI

struct MeToolbar: View {
  @EnvironmentObject private var settingsStore: BangumiSettingsStore

  let sortOrder: MeCollectionSortOrder
  let selectedTag: MeCollectionTag
  let availableTags: [MeCollectionTag]
  let onSortSelect: (MeCollectionSortOrder) -> Void
  let onTagSelect: (MeCollectionTag) -> Void
  let onRefresh: () -> Void
  let onNotifications: () -> Void
  let onClearCache: () -> Void
  let onProfile: () -> Void
  let onLogout: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      sortMenu
      tagMenu
      moreMenu
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.horizontal, 16)
  }

  private var sortMenu: some View {
    Menu {
      ForEach(MeCollectionSortOrder.allCases) { order in
        Button {
          onSortSelect(order)
        } label: {
          Label(order.title, systemImage: order.systemImage)
        }
      }
    } label: {
      toolbarChip(title: sortOrder.title, systemImage: sortOrder.systemImage)
    }
  }

  private var tagMenu: some View {
    Menu {
      ForEach(availableTags) { tag in
        Button(tag.title) {
          onTagSelect(tag)
        }
      }
    } label: {
      toolbarChip(title: selectedTag.title == "全部" ? "标签" : selectedTag.title, systemImage: "tag")
    }
  }

  private var moreMenu: some View {
    Menu {
      Button("刷新收藏", systemImage: "arrow.clockwise", action: onRefresh)
      Button("通知管理", systemImage: "bell.badge", action: onNotifications)
      Button("查看资料", systemImage: "person.crop.circle", action: onProfile)

      Picker("主题", selection: $settingsStore.preferredTheme) {
        ForEach(PreferredTheme.allCases) { theme in
          Text(theme.title).tag(theme)
        }
      }

      Button("清理缓存", systemImage: "trash", action: onClearCache)
      Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, action: onLogout)
    } label: {
      toolbarChip(title: "更多", systemImage: "ellipsis")
    }
  }

  private func toolbarChip(title: String, systemImage: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
      Text(title)
        .lineLimit(1)
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(.primary)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
  }
}
