import SwiftUI
import UIKit

enum BangumiDesign {
  static let screenHorizontalPadding: CGFloat = 16
  static let rowSpacing: CGFloat = 12
  static let sectionSpacing: CGFloat = 8
  static let cardPadding: CGFloat = 12
  static let cardRadius: CGFloat = 18
  static let heroRadius: CGFloat = 28
  static let rootTabBarClearance: CGFloat = 96
}

enum BangumiTypography {
  static let miSansRegular = "MiSans-Regular"
  static let miSansMedium = "MiSans-Medium"
  static let miSansBold = "MiSans-Bold"
  static let detailLinkUIColor = UIColor(red: 0.92, green: 0.42, blue: 0.60, alpha: 1)
  static let detailLinkColor = Color(uiColor: detailLinkUIColor)

  static func detailFont(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
    switch weight {
    case .bold, .heavy, .black:
      return .custom(miSansBold, size: size)
    case .medium, .semibold:
      return .custom(miSansMedium, size: size)
    default:
      return .custom(miSansRegular, size: size)
    }
  }

  static func detailUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    let name: String
    switch weight {
    case .bold, .heavy, .black:
      name = miSansBold
    case .medium, .semibold:
      name = miSansMedium
    default:
      name = miSansRegular
    }

    return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
  }
}

enum BangumiDiscoveryDesign {
  static let screenSpacing: CGFloat = 22
  static let cardSpacing: CGFloat = 16
  static let heroPageInset: CGFloat = BangumiDesign.screenHorizontalPadding
  static let heroHeight: CGFloat = 510
  static let heroRadius: CGFloat = 32
  static let sectionRadius: CGFloat = 30
  static let rowRadius: CGFloat = 24
  static let sectionPadding: CGFloat = 18
  static let rowPadding: CGFloat = 14
  static let rowCoverWidth: CGFloat = 74
  static let rowCoverHeight: CGFloat = 98
}

enum BangumiDiscoveryCopy {
  static let eyebrow = "DISCOVER"
  static let title = "发现"
  static let summary = "把一周放送表排成更像刊物首页的卡片流。"
  static let heroEyebrow = "SPOTLIGHT"
  static let heroTitle = "今日主打"
  static let sectionEyebrow = "SWIMLANE"
  static let sectionSummary = "按星期整理的放送清单，保留时间线但强化卡片层级。"
}

enum BangumiSearchDesign {
  static let barHeight: CGFloat = 56
  static let searchRadius: CGFloat = 28
  static let panelRadius: CGFloat = 26
  static let panelPadding: CGFloat = 18
  static let resultRadius: CGFloat = 28
  static let resultCoverWidth: CGFloat = 76
  static let resultCoverHeight: CGFloat = 100
}
