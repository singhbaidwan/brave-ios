// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import MediaPlayer
import AVKit
import AVFoundation
import Shared
import Data

private let log = Logger.browserLogger

//class PlaylistMediaInfo: NSObject {
//    private weak var playerView: VideoView?
//    private var webLoader: PlaylistWebLoader?
//    private var playerStatusObserver: PlaylistPlayerStatusObserver?
//    private var rateObserver: NSKeyValueObservation?
//    public var nowPlayingInfo: PlaylistInfo? {
//        didSet {
//            updateNowPlayingMediaInfo()
//        }
//    }
//    
//    public init(playerView: VideoView) {
//        self.playerView = playerView
//        super.init()
//        
//        
//        UIApplication.shared.beginReceivingRemoteControlEvents()
//        updateNowPlayingMediaInfo()
//        rateObserver = playerView.player.observe(\AVPlayer.rate, changeHandler: { [weak self] _, _ in
//            self?.updateNowPlayingMediaInfo()
//        })
//    }
//    
//    deinit {
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
//        self.webLoader?.removeFromSuperview()
//        UIApplication.shared.endReceivingRemoteControlEvents()
//    }
//    
//    func updateNowPlayingMediaInfo() {
//        if let nowPlayingItem = self.nowPlayingInfo {
//            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
//                MPNowPlayingInfoPropertyMediaType: "Audio",
//                MPMediaItemPropertyTitle: nowPlayingItem.name,
//                MPMediaItemPropertyArtist: URL(string: nowPlayingItem.pageSrc)?.baseDomain ?? nowPlayingItem.pageSrc,
//                MPMediaItemPropertyPlaybackDuration: TimeInterval(nowPlayingItem.duration),
//                MPNowPlayingInfoPropertyPlaybackRate: Double(self.playerView?.player.rate ?? 1.0),
//                MPNowPlayingInfoPropertyPlaybackProgress: Float(0.0),
//                MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(self.playerView?.player.currentTime().seconds ?? 0.0)
//            ]
//        } else {
//            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
//        }
//    }
//    
//    func updateNowPlayingMediaArtwork(image: UIImage?) {
//        if let image = image {
//            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
//                // Do not resize image here.
//                // According to Apple it isn't necessary to use expensive resize operations
//                return image
//            })
//        }
//    }
//}

class PlaylistPlayerStatusObserver: NSObject {
    private var context = 0
    private weak var player: AVPlayer?
    private var item: AVPlayerItem?
    private var onStatusChanged: (AVPlayerItem.Status) -> Void
    private var currentItemObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    
    init(player: AVPlayer, onStatusChanged: @escaping (AVPlayerItem.Status) -> Void) {
        self.onStatusChanged = onStatusChanged
        super.init()
        
        self.player = player
        currentItemObserver = player.observe(\AVPlayer.currentItem, options: [.new], changeHandler: { [weak self] _, change in
            guard let self = self else { return }
            
            if let newItem = change.newValue {
                self.item = newItem
                self.itemStatusObserver = newItem?.observe(\AVPlayerItem.status, options: [.new], changeHandler: { [weak self] _, change in
                    guard let self = self else { return }
                    
                    let status = change.newValue ?? .unknown
                    switch status {
                    case .readyToPlay:
                        log.debug("Player Item Status: Ready")
                        self.onStatusChanged(.readyToPlay)
                    case .failed:
                        log.debug("Player Item Status: Failed")
                        self.onStatusChanged(.failed)
                    case .unknown:
                        log.debug("Player Item Status: Unknown")
                        self.onStatusChanged(.unknown)
                    @unknown default:
                        assertionFailure("Unknown Switch Case for AVPlayerItemStatus")
                    }
                })
            }
        })
    }
}
