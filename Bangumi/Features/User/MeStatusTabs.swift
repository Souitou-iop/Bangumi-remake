import SwiftUI

struct MeStatusTabs: View {
  let summaries: [MeStatusSummary]
  let selectedStatus: CollectionStatus
  let isCompact: Bool
  let onSelect: (CollectionStatus) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: isCompact ? 10 : 12) {
        ForEach(summaries) { summary in
          Button {
            onSelect(summary.status)
          } label: {
            VStack(alignment: .leading, spacing: isCompact ? 3 : 6) {
              Text(summary.status.title)
                .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.bold))
              Text("\(summary.count)")
                .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.semibold))
                .foregroundStyle(isSelected(summary.status) ? Color.accentColor : .secondary)
            }
            .frame(width: isCompact ? 88 : 108, alignment: .leading)
            .padding(.horizontal, isCompact ? 14 : 18)
            .padding(.vertical, isCompact ? 12 : 16)
            .background(background(for: summary.status))
            .overlay(alignment: .bottom) {
              if isSelected(summary.status) && !isCompact {
                Capsule()
                  .fill(Color.accentColor)
                  .frame(width: 38, height: 5)
                  .padding(.bottom, 6)
              }
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, isCompact ? 6 : 2)
    }
  }

  private func isSelected(_ status: CollectionStatus) -> Bool {
    selectedStatus == status
  }

  @ViewBuilder
  private func background(for status: CollectionStatus) -> some View {
    if isCompact {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(isSelected(status) ? Color.accentColor.opacity(0.14) : Color(uiColor: .secondarySystemBackground))
    } else {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(isSelected(status) ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground))
        .shadow(color: .black.opacity(isSelected(status) ? 0.06 : 0), radius: 12, y: 4)
    }
  }
}
