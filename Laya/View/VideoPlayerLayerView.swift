//
//  VideoPlayerLayerView.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import SwiftUI
import AVFoundation

/// Thin bridge from an `AVPlayer` to a raw `AVPlayerLayer`-backed `UIView`.
///
/// We deliberately host the layer directly rather than using SwiftUI's
/// `VideoPlayer` / `AVPlayerViewController`: it strips the system transport
/// controls and gives the journey feed full visual control, and it's the
/// lowest-latency way to show a pooled player (the layer just points at whatever
/// `AVPlayer` the feed manager hands it).
///
/// The entrance crossfade is handled entirely by the SwiftUI `.transition(.opacity)`
/// on the player phase: `AVPlayerLayer` is an ordinary `CALayer`, so its opacity
/// cascades through Core Animation. As long as the layer is in the tree while the
/// container's opacity animates (the bundled entry clip is ready well within the
/// fade), the video rides that crossfade with the rest of the chrome — no separate
/// UIKit alpha animation needed.
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Only repoint when the player actually changes so reused cells don't
        // tear down and rebuild the layer's pipeline on every layout pass.
        if uiView.playerLayer.player != player {
            uiView.playerLayer.player = player
        }
    }
}

/// A `UIView` whose backing layer *is* an `AVPlayerLayer`, so the video fills the
/// view without an extra sublayer to size/keep-in-sync.
final class PlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
