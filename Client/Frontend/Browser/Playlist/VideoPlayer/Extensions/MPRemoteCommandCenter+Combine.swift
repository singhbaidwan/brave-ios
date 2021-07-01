// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import MediaPlayer
import Combine

//class PlaylistControlCenterManager: NSObject {
//    private weak var playerView: VideoView?
//    private var commandObservers = Set<AnyCancellable>()
//    private var rateObserver: NSKeyValueObservation?
//    public var nowPlayingInfo: PlaylistInfo? {
//        didSet {
//            updateNowPlayingMediaInfo()
//        }
//    }
//    
//    init(playerView: VideoView) {
//        self.playerView = playerView
//        super.init()
//    }
//    
//    private func addCommandObservers() {
//        updateNowPlayingMediaInfo()
//        rateObserver = playerView?.player.observe(\AVPlayer.rate, changeHandler: { [weak self] _, _ in
//            self?.updateNowPlayingMediaInfo()
//        })
//    }
//    
//    deinit {
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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

extension MPRemoteCommandCenter {
    func publisher(for event: Command) -> EventPublisher {
        EventPublisher(command: event.command)
    }
    
    enum Command {
        case pauseCommand
        case playCommand
        case stopCommand
        case togglePlayPauseCommand
        case enableLanguageOptionCommand
        case disableLanguageOptionCommand
        case changePlaybackRateCommand
        case changeRepeatModeCommand
        case changeShuffleModeCommand
        case nextTrackCommand
        case previousTrackCommand
        case skipForwardCommand
        case skipBackwardCommand
        case seekForwardCommand
        case seekBackwardCommand
        case changePlaybackPositionCommand
        case ratingCommand
        case likeCommand
        case dislikeCommand
        case bookmarkCommand
        
        var command: MPRemoteCommand {
            let center = MPRemoteCommandCenter.shared()
            switch self {
            case .pauseCommand: return center.pauseCommand
            case .playCommand: return center.playCommand
            case .stopCommand: return center.stopCommand
            case .togglePlayPauseCommand: return center.togglePlayPauseCommand
            case .enableLanguageOptionCommand: return center.enableLanguageOptionCommand
            case .disableLanguageOptionCommand: return center.disableLanguageOptionCommand
            case .changePlaybackRateCommand: return center.changePlaybackRateCommand
            case .changeRepeatModeCommand: return center.changeRepeatModeCommand
            case .changeShuffleModeCommand: return center.changeShuffleModeCommand
            case .nextTrackCommand: return center.nextTrackCommand
            case .previousTrackCommand: return center.previousTrackCommand
            case .skipForwardCommand: return center.skipForwardCommand
            case .skipBackwardCommand: return center.skipBackwardCommand
            case .seekForwardCommand: return center.seekForwardCommand
            case .seekBackwardCommand: return center.seekBackwardCommand
            case .changePlaybackPositionCommand: return center.changePlaybackPositionCommand
            case .ratingCommand: return center.ratingCommand
            case .likeCommand: return center.likeCommand
            case .dislikeCommand: return center.dislikeCommand
            case .bookmarkCommand: return center.bookmarkCommand
            }
        }
    }
}

// A publisher and subscriber for MPRemoteCommand observers
extension MPRemoteCommandCenter {
    struct EventPublisher: Publisher {
        typealias Output = MPRemoteCommandEvent
        typealias Failure = Never
        
        private var command: MPRemoteCommand
        
        init(command: MPRemoteCommand) {
            self.command = command
        }
        
        func receive<S: Subscriber>(
            subscriber: S
        ) where S.Input == Output, S.Failure == Failure {
            let subscription = EventSubscription<S>()
            subscription.target = subscriber
            
            subscriber.receive(subscription: subscription)
            subscription.observe(command)
        }
    }
    
    private class EventSubscription<Target: Subscriber>: Subscription
            where Target.Input == MPRemoteCommandEvent {
        
        var target: Target?
        
        private var command: MPRemoteCommand?
        private var observer: Any?
        
        func request(_ demand: Subscribers.Demand) {}
        
        func cancel() {
            command?.removeTarget(observer)
            target = nil
        }
        
        func observe(_ command: MPRemoteCommand) {
            self.command = command
            observer = command.addTarget(handler: eventHandler)
        }
        
        private func eventHandler(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
            _ = target?.receive(event)
            return .success
        }
    }
}
