import AVFoundation
import Combine
import Foundation

@MainActor
final class ExplorePlayerCoordinator: ObservableObject {
    @Published private(set) var isUserPaused = false

    private var players: [UUID: AVQueuePlayer] = [:]
    private var loopers: [UUID: AVPlayerLooper] = [:]
    private var playingID: UUID?

    func player(for id: UUID) -> AVQueuePlayer? {
        players[id]
    }

    func prepare(window: [ExploreVideoItem], playingID: UUID?, shouldPlay: Bool) {
        let keepIDs = Set(window.map(\.id))

        for item in window where players[item.id] == nil {
            attach(item)
        }

        for id in Array(players.keys) where !keepIDs.contains(id) {
            detach(id)
        }

        if self.playingID != playingID {
            isUserPaused = false
            self.playingID = playingID
        }

        for (id, player) in players {
            let isCurrent = id == playingID
            if isCurrent, shouldPlay, !isUserPaused {
                if player.timeControlStatus != .playing {
                    player.play()
                }
            } else if player.timeControlStatus == .playing {
                player.pause()
            }
        }
    }

    func togglePlayback() {
        guard let playingID, let player = players[playingID] else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isUserPaused = true
        } else {
            isUserPaused = false
            player.play()
        }
    }

    func pauseAll() {
        for player in players.values where player.timeControlStatus == .playing {
            player.pause()
        }
    }

    func tearDown() {
        for id in Array(players.keys) {
            detach(id)
        }
        playingID = nil
        isUserPaused = false
    }

    private func attach(_ item: ExploreVideoItem) {
        let playerItem = AVPlayerItem(url: item.videoURL)
        playerItem.preferredForwardBufferDuration = 6

        let player = AVQueuePlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = false
        player.actionAtItemEnd = .none

        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        players[item.id] = player
        loopers[item.id] = looper
        objectWillChange.send()
    }

    private func detach(_ id: UUID) {
        players[id]?.pause()
        players[id]?.removeAllItems()
        players.removeValue(forKey: id)
        loopers.removeValue(forKey: id)
        objectWillChange.send()
    }
}
