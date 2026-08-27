import Foundation
import UIKit

/// 封面图内存缓存：同时记住图片与展示用高宽比，减少瀑布流二次加载时的高度跳动。
final class RecipeCoverImageCache {
    static let shared = RecipeCoverImageCache()

    struct Entry {
        let image: UIImage
        let aspect: CGFloat
    }

    private let lock = NSLock()
    private let cache = NSCache<NSString, CacheBox>()
    private var inFlight: [String: Task<Entry?, Never>] = [:]

    private final class CacheBox: NSObject {
        let entry: Entry
        init(_ entry: Entry) { self.entry = entry }
    }

    private init() {
        cache.countLimit = 120
    }

    func entry(for url: URL) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: url.absoluteString as NSString)?.entry
    }

    func aspect(for url: URL, fallback: CGFloat) -> CGFloat {
        entry(for: url)?.aspect ?? fallback
    }

    func prefetch(urls: [URL], minAspect: CGFloat, maxAspect: CGFloat) {
        for url in urls {
            _ = Task {
                _ = await image(for: url, minAspect: minAspect, maxAspect: maxAspect)
            }
        }
    }

    func image(
        for url: URL,
        minAspect: CGFloat,
        maxAspect: CGFloat
    ) async -> Entry? {
        if let cached = entry(for: url) {
            return cached
        }

        let key = url.absoluteString
        let existingTask: Task<Entry?, Never>? = {
            lock.lock()
            defer { lock.unlock() }
            return inFlight[key]
        }()

        if let existingTask {
            return await existingTask.value
        }

        let task = Task<Entry?, Never> {
            defer {
                lock.lock()
                inFlight[key] = nil
                lock.unlock()
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    return nil
                }

                guard let image = UIImage(data: data), image.size.width > 0 else {
                    return nil
                }

                let raw = image.size.height / image.size.width
                let aspect = min(max(raw, minAspect), maxAspect)
                let entry = Entry(image: image, aspect: aspect)
                store(entry, for: url)
                return entry
            } catch {
                return nil
            }
        }

        lock.lock()
        inFlight[key] = task
        lock.unlock()

        return await task.value
    }

    private func store(_ entry: Entry, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(CacheBox(entry), forKey: url.absoluteString as NSString)
    }

    static func estimatedAspect(forRecipeID id: Int) -> CGFloat {
        let candidates: [CGFloat] = [0.82, 0.95, 1.05, 1.2, 1.35, 1.5]
        return candidates[abs(id) % candidates.count]
    }

    static func clampAspect(_ raw: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(raw, min), max)
    }
}
