// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import MediaPlayer
import Combine

class PlaylistControlCenterManager: NSObject {
    private weak var playerView: VideoView?
    private var commandObservers = Set<AnyCancellable>()
    
    init(playerView: VideoView) {
        self.playerView = playerView
        super.init()
    }
    
    private func addCommandObservers() {
        let center = MPRemoteCommandCenter.shared()
        center.publisher(for: .pauseCommand).sink { [weak self] _ in
            self?.playerView?.pause()
        }.store(in: &commandObservers)
        
        center.publisher(for: .playCommand).sink { [weak self] _ in
            self?.playerView?.play()
        }.store(in: &commandObservers)
        
        center.publisher(for: .stopCommand).sink { [weak self] _ in
            self?.playerView?.stop()
        }.store(in: &commandObservers)
        
        center.publisher(for: .changeRepeatModeCommand).sink { [weak self] _ in
            //self?.playerView?.repeatState = .repeatOne
        }.store(in: &commandObservers)
        
        center.publisher(for: .changeShuffleModeCommand).sink { [weak self] _ in
            
        }.store(in: &commandObservers)
        
        center.publisher(for: .previousTrackCommand).sink { [weak self] _ in
            self?.playerView?.previous()
        }.store(in: &commandObservers)
        
        center.publisher(for: .nextTrackCommand).sink { [weak self] _ in
            self?.playerView?.next()
        }.store(in: &commandObservers)
        
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15.0)]
        center.publisher(for: .skipBackwardCommand).sink { [weak self] event in
            guard let self = self,
                  let playerView = self.playerView,
                  let event = event as? MPSkipIntervalCommandEvent else { return }
            
            let currentTime = playerView.player.currentTime()
            playerView.seekBackwards()
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTime.seconds - event.interval)
        }.store(in: &commandObservers)
        
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 15.0)]
        center.publisher(for: .skipForwardCommand).sink { [weak self] event in
            guard let self = self,
                  let playerView = self.playerView,
                  let event = event as? MPSkipIntervalCommandEvent else { return }
            
            let currentTime = playerView.player.currentTime()
            playerView.seekForwards()
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTime.seconds + event.interval)
        }.store(in: &commandObservers)
        
        center.publisher(for: .changePlaybackPositionCommand).sink { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.playerView?.seek(to: event.positionTime)
            }
        }.store(in: &commandObservers)
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
//        updateNowPlayingMediaInfo()
//        rateObserver = playerView.player.observe(\AVPlayer.rate, changeHandler: { [weak self] _, _ in
//            self?.updateNowPlayingMediaInfo()
//        })
    }
    
    deinit {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        //self.webLoader?.removeFromSuperview()
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}

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
            command.addTarget(subscription, action: #selector(subscription.eventHandler))
        }
    }
    
    private class EventSubscription<Target: Subscriber>: Subscription
            where Target.Input == MPRemoteCommandEvent {
        var target: Target?
        func request(_ demand: Subscribers.Demand) {}
        func cancel() {
            target = nil
        }
        
        @objc
        func eventHandler(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
            _ = target?.receive(event)
            return .success
        }
    }
}
