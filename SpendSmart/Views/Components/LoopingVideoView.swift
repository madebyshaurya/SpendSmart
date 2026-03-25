import AVFoundation
import SwiftUI

struct LoopingVideoView: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .clear  // Ensure transparent background

        let fileName = name
        let fileExt = "mp4"

        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExt) {
            let playerItem = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

            view.playerLayer.player = queuePlayer
            view.playerLayer.videoGravity = .resizeAspectFill

            queuePlayer.isMuted = true
            configureAudioSession()
            queuePlayer.actionAtItemEnd = .none
            queuePlayer.playImmediately(atRate: 1.0)

            // Keep references alive
            context.coordinator.player = queuePlayer
            context.coordinator.playerLooper = playerLooper
        } else {
            print("❌ LoopingVideoView Error: Could not find \(fileName).\(fileExt) in Main Bundle.")
            // Debugging helper: Print all mp4s found
            let allMp4s =
                Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? []
            print("   Available MP4s: \(allMp4s.map { $0.lastPathComponent })")
        }

        return view
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("⚠️ LoopingVideoView AudioSession error: \(error)")
        }
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.videoGravity = .resizeAspectFill
        if let player = context.coordinator.player {
            player.isMuted = true
            if player.rate == 0 {
                player.playImmediately(atRate: 1.0)
            } else if player.rate != 1.0 {
                player.rate = 1.0
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLooper: AVPlayerLooper?
        var player: AVQueuePlayer?
    }

    // Custom UIView to handle layout updates automatically
    class PlayerUIView: UIView {
        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
