import SwiftUI

struct MeCollectionList: View {
  @EnvironmentObject private var model: BangumiAppModel

  let status: CollectionStatus
  let items: [BangumiCollectionItem]
  let isLoading: Bool
  let canLoadMore: Bool
  let errorMessage: String?
  let onLoadMore: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let errorMessage, !errorMessage.isEmpty, items.isEmpty {
        MeEmptyStateCard(
          title: "读取失败",
          subtitle: errorMessage,
          systemImage: "exclamationmark.triangle"
        )
      } else if isLoading && items.isEmpty {
        HStack {
          Spacer()
          ProgressView("正在加载 \(status.title)")
          Spacer()
        }
        .padding(.vertical, 36)
      } else if items.isEmpty {
        MeEmptyStateCard(
          title: "\(status.title)列表为空",
          subtitle: "当前状态下还没有可展示的动画收藏。",
          systemImage: "square.stack.3d.up.slash"
        )
      } else {
        ForEach(items) { item in
          Button {
            model.presentedRoute = .subject(item.subjectID)
          } label: {
            MeCollectionRow(item: item, status: status)
          }
          .buttonStyle(.plain)
        }

        if canLoadMore {
          Button(action: onLoadMore) {
            HStack {
              Spacer()
              Text("继续加载")
                .font(.subheadline.weight(.semibold))
              Spacer()
            }
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct MeCollectionRow: View {
  let item: BangumiCollectionItem
  let status: CollectionStatus

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      BangumiRemoteImage(url: item.subject.images?.best) {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.secondary.opacity(0.12))
          .overlay {
            Image(systemName: "photo")
              .foregroundStyle(.secondary)
          }
      }
      .scaledToFill()
      .frame(width: 104, height: 144)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          Text(item.meDisplayTitle)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)

          Spacer(minLength: 8)

          Text(status.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }

        if let secondaryTitle = item.meSecondaryTitle {
          Text(secondaryTitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        if !item.meMetadataLine.isEmpty {
          Text(item.meMetadataLine)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        Spacer(minLength: 0)

        if let updatedAt = item.meUpdatedAtText {
          Text(updatedAt)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
    }
    .padding(14)
    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct MeEmptyStateCard: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(.secondary)

      Text(title)
        .font(.title3.weight(.bold))

      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 42)
    .padding(.horizontal, 20)
    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}
