import Foundation

struct ExploreVideoItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let caption: String
    let videoURL: URL

    func recycled(id: UUID = UUID()) -> ExploreVideoItem {
        ExploreVideoItem(
            id: id,
            title: title,
            author: author,
            caption: caption,
            videoURL: videoURL
        )
    }
}

enum ExploreMockCatalog {
    private struct Seed {
        let resourceName: String
        let title: String
        let author: String
        let caption: String
    }

    private static let seedDefs: [Seed] = [
        Seed(resourceName: "food_01", title: "炉火里的一锅番茄", author: "@厨房值班室", caption: "本地样片 1，用来调全屏下滑。"),
        Seed(resourceName: "food_02", title: "周末的慢炖午后", author: "@小火慢炖", caption: "本地样片 2，切到上下条应立刻起播。"),
        Seed(resourceName: "food_03", title: "清冰箱灵感", author: "@存货食堂", caption: "本地样片 3，验证预加载窗口。"),
        Seed(resourceName: "food_04", title: "夜市里的烟火气", author: "@街边锅气", caption: "本地样片 4，轻点可暂停。"),
        Seed(resourceName: "food_05", title: "一口气看完的快手面", author: "@十分钟晚饭", caption: "本地样片 5，循环播放看手感。"),
        Seed(resourceName: "food_06", title: "雨天的一碗热汤", author: "@回家吃饭", caption: "本地样片 6，滑到底会再拼一批。")
    ]

    /// App 包内的 6 条美食测试视频，不走网络。
    static let seeds: [ExploreVideoItem] = seedDefs.compactMap { seed in
        guard let videoURL = bundledVideoURL(named: seed.resourceName) else {
            assertionFailure("缺少测试视频 \(seed.resourceName).mp4")
            return nil
        }
        return ExploreVideoItem(
            id: UUID(),
            title: seed.title,
            author: seed.author,
            caption: seed.caption,
            videoURL: videoURL
        )
    }

    static func makeBatch() -> [ExploreVideoItem] {
        seeds.map { $0.recycled() }
    }

    private static func bundledVideoURL(named name: String) -> URL? {
        let subdirectories = ["Resources/ExploreVideos", "ExploreVideos", nil]
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: subdirectory) {
                return url
            }
        }

        let matches = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? []
        return matches.first { $0.deletingPathExtension().lastPathComponent == name }
    }
}
