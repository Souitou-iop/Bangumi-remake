import SwiftUI

struct MeStatusTabs: View {
  let summaries: [MeStatusSummary]
  let selectedStatus: CollectionStatus
  let isCompact: Bool
  let onSelect: (CollectionStatus) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
      Picker("收藏状态", selection: selectionBinding) {
        ForEach(summaries) { summary in
          Text(summary.status.title)
            .tag(summary.status)
        }
      }
      .pickerStyle(.segmented)

      if !isCompact, let selectedSummary {
        Text("当前\(selectedSummary.status.title) \(selectedSummary.count) 部")
          .font(.footnote.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 2)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, isCompact ? 6 : 2)
  }

  private var selectionBinding: Binding<CollectionStatus> {
    Binding(
      get: { selectedStatus },
      set: { onSelect($0) }
    )
  }

  private var selectedSummary: MeStatusSummary? {
    summaries.first(where: { $0.status == selectedStatus })
  }
}
