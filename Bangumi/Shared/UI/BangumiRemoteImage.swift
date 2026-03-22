import SwiftUI
import UIKit

private actor BangumiRemoteImageStore {
  static let shared = BangumiRemoteImageStore()

  private let cache = NSCache<NSURL, UIImage>()
  private var inFlightTasks: [NSURL: Task<UIImage?, Never>] = [:]

  func cachedImage(for url: NSURL) -> UIImage? {
    cache.object(forKey: url)
  }

  func image(for url: URL) async -> UIImage? {
    let key = url as NSURL

    if let cached = cache.object(forKey: key) {
      return cached
    }

    if let existingTask = inFlightTasks[key] {
      return await existingTask.value
    }

    let task = Task<UIImage?, Never> {
      defer { Task { await self.clearTask(for: key) } }

      var request = URLRequest(url: url)
      request.cachePolicy = .returnCacheDataElseLoad

      do {
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else { return nil }
        let prepared = image.preparingForDisplay() ?? image
        await self.store(prepared, for: key)
        return prepared
      } catch {
        return nil
      }
    }

    inFlightTasks[key] = task
    return await task.value
  }

  private func store(_ image: UIImage, for key: NSURL) {
    let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
    cache.setObject(image, forKey: key, cost: cost)
  }

  private func clearTask(for key: NSURL) {
    inFlightTasks[key] = nil
  }
}

@MainActor
private final class BangumiRemoteImageLoader: ObservableObject {
  @Published private(set) var image: UIImage?

  private var currentURL: URL?
  private var loadTask: Task<Void, Never>?

  deinit {
    loadTask?.cancel()
  }

  func load(from url: URL?) {
    guard currentURL != url else { return }
    currentURL = url
    loadTask?.cancel()

    guard let url else {
      image = nil
      return
    }

    loadTask = Task { [weak self] in
      guard let self else { return }

      if let cached = await BangumiRemoteImageStore.shared.cachedImage(for: url as NSURL) {
        if !Task.isCancelled {
          image = cached
        }
        return
      }

      let loadedImage = await BangumiRemoteImageStore.shared.image(for: url)
      guard !Task.isCancelled, currentURL == url else { return }
      image = loadedImage
    }
  }
}

struct BangumiRemoteImage<Placeholder: View>: View {
  let url: URL?
  let contentMode: ContentMode
  @ViewBuilder let placeholder: () -> Placeholder

  @StateObject private var loader = BangumiRemoteImageLoader()

  init(
    url: URL?,
    contentMode: ContentMode = .fill,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    self.url = url
    self.contentMode = contentMode
    self.placeholder = placeholder
  }

  var body: some View {
    Group {
      if let image = loader.image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        placeholder()
      }
    }
    .task(id: url) {
      loader.load(from: url)
    }
  }
}
