import SwiftUI

struct MeHeaderView: View {
  let user: BangumiUser
  let collapseProgress: CGFloat
  let backgroundURL: URL?
  let onProfileTap: () -> Void

  var body: some View {
    ZStack {
      BangumiRemoteImage(url: backgroundURL) {
        LinearGradient(
          colors: [
            Color.accentColor.opacity(0.7),
            Color.accentColor.opacity(0.28),
            Color.black.opacity(0.18)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
      .scaledToFill()
      .overlay {
        LinearGradient(
          colors: [
            Color.black.opacity(0.18),
            Color.black.opacity(0.48),
            Color.black.opacity(0.68)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
      .clipped()
      .overlay {
        Rectangle()
          .fill(.ultraThinMaterial.opacity(0.12))
      }

      VStack(spacing: 14) {
        Button(action: onProfileTap) {
          BangumiRemoteImage(url: user.avatar?.best) {
            Circle()
              .fill(Color.white.opacity(0.18))
              .overlay {
                Image(systemName: "person.fill")
                  .foregroundStyle(.white.opacity(0.88))
              }
          }
          .scaledToFill()
          .frame(width: 112, height: 112)
          .clipShape(Circle())
          .overlay {
            Circle()
              .stroke(Color.white.opacity(0.92), lineWidth: 4)
          }
          .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(1 - min(collapseProgress, 1) * 0.08)

        VStack(spacing: 6) {
          Text(user.displayName)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

          Text("@\(user.username)")
            .font(.headline)
            .foregroundStyle(.white.opacity(0.9))
        }

        if let sign = user.sign?.trimmingCharacters(in: .whitespacesAndNewlines), !sign.isEmpty {
          Text(sign)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.82))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 24)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .padding(.horizontal, 20)
      .padding(.vertical, 20)
    }
    .frame(height: 360)
    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    .padding(.horizontal, 12)
    .padding(.top, 8)
  }
}
