import AVFoundation
import SwiftUI

struct ExploreFeedView: View {
    @EnvironmentObject private var navigationStore: AppNavigationStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var feed = ExploreFeedStore()
    @StateObject private var players = ExplorePlayerCoordinator()

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(feed.items) { item in
                        ExploreVideoPage(
                            item: item,
                            player: players.player(for: item.id),
                            isActive: item.id == feed.currentID,
                            isPaused: item.id == feed.currentID && players.isUserPaused,
                            isLiked: feed.isLiked(item.id),
                            onTogglePlay: {
                                players.togglePlayback()
                            },
                            onToggleLike: {
                                feed.toggleLike(for: item.id)
                            }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $feed.currentID)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.black.opacity(0.28), for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            activateAudioSession()
            syncPlayers()
        }
        .onDisappear {
            players.pauseAll()
        }
        .onChange(of: feed.currentID) { _, _ in
            feed.appendIfNeeded()
            syncPlayers()
        }
        .onChange(of: navigationStore.selectedTab) { _, tab in
            if tab == .explore {
                activateAudioSession()
            }
            syncPlayers()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                players.pauseAll()
            } else if navigationStore.selectedTab == .explore {
                syncPlayers()
            }
        }
    }

    private func syncPlayers() {
        players.prepare(
            window: feed.windowItems(),
            playingID: feed.currentID,
            shouldPlay: navigationStore.selectedTab == .explore && scenePhase == .active
        )
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 本地交互阶段忽略音频会话失败，避免打断浏览。
        }
    }
}

private struct ExploreVideoPage: View {
    let item: ExploreVideoItem
    let player: AVPlayer?
    let isActive: Bool
    let isPaused: Bool
    let isLiked: Bool
    let onTogglePlay: () -> Void
    let onToggleLike: () -> Void

    var body: some View {
        ZStack {
            Color.black
            ExplorePlayerLayerView(player: player)
            linearOverlay
            bottomCopy
            rightActions
            if isPaused {
                pauseBadge
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isActive else { return }
            onTogglePlay()
        }
    }

    private var linearOverlay: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.18),
                Color.clear,
                Color.black.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var bottomCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            Text(item.author)
                .font(.headline.weight(.semibold))
            Text(item.title)
                .font(.title3.weight(.bold))
            Text(item.caption)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.trailing, 76)
        .padding(.bottom, 18)
        .allowsHitTesting(false)
    }

    private var rightActions: some View {
        VStack(spacing: 18) {
            Spacer()
            actionButton(
                systemImage: isLiked ? "heart.fill" : "heart",
                title: L10n.text(L10n.Explore.like),
                tint: isLiked ? Color.pink : .white,
                action: onToggleLike
            )
            actionButton(
                systemImage: "ellipsis.bubble",
                title: L10n.text(L10n.Explore.comment),
                action: {}
            )
            actionButton(
                systemImage: "arrowshape.turn.up.right",
                title: L10n.text(L10n.Explore.share),
                action: {}
            )
        }
        .padding(.trailing, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var pauseBadge: some View {
        Image(systemName: "pause.fill")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(22)
            .background(.black.opacity(0.28), in: Circle())
            .allowsHitTesting(false)
    }

    private func actionButton(
        systemImage: String,
        title: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.22), in: Circle())
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExploreFeedView()
        .environmentObject(AppNavigationStore(selectedTab: .explore))
}
