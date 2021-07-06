// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Combine
import MediaPlayer

/// Lightweight class that manages a single MediaPlayer item
/// The MediaPlayer is then passed to any controller that needs to use it.
class PlaylistCarplayManager: NSObject {
    private var carPlayStatusObservers = Set<AnyCancellable>()
    private let contentManager = MPPlayableContentManager.shared()
    private let carPlayStatus = CurrentValueSubject<Bool, Never>(false)
    private var carPlayController: PlaylistCarplayController?
    private weak var mediaPlayer: MediaPlayer?
    
    // There can only ever be one instance of this class
    // Because there can only be a single AudioSession and MediaPlayer
    // in use at any given moment
    static let shared = {
        PlaylistCarplayManager()
    }()
    
    private override init() {
        super.init()
        
        // We need to observe when CarPlay is connected
        // That way, we can  determine where the controls are coming from for Playlist
        // OR determine where the AudioSession is outputting
        
        AVAudioSession.sharedInstance().currentRoute.outputs.publisher.contains(where: { $0.portType == .carAudio }).sink { [weak self] isCarPlayAvailable in
            self?.attemptInterfaceConnection(isCarPlayAvailable: isCarPlayAvailable)
        }.store(in: &carPlayStatusObservers)
        
        UIDevice.current.publisher(for: \.userInterfaceIdiom).map({ $0 == .carPlay }).sink { [weak self] isCarPlayAvailable in
            self?.attemptInterfaceConnection(isCarPlayAvailable: isCarPlayAvailable)
        }.store(in: &carPlayStatusObservers)
        
        carPlayController = getCarPlayController()
    }
    
    deinit {
        carPlayController = nil
        mediaPlayer = nil
    }
    
    func getCarPlayController() -> PlaylistCarplayController {
        // If there is no media player, create one,
        // pass it to the car-play controller
        let mediaPlayer = self.mediaPlayer ?? MediaPlayer()
        let carPlayController = PlaylistCarplayController(player: mediaPlayer, contentManager: contentManager)
        self.mediaPlayer = mediaPlayer
        return carPlayController
    }
    
    func getPlaylistController() -> PlaylistViewController {
        // If there is no media player, create one,
        // pass it to the play-list controller
        let mediaPlayer = self.mediaPlayer ?? MediaPlayer()
        let playlistController = PlaylistViewController(player: mediaPlayer)
        self.mediaPlayer = mediaPlayer
        return playlistController
    }
    
    func attemptInterfaceConnection(isCarPlayAvailable: Bool) {
        // If there is no media player, create one,
        // pass it to the carplay controller
//        if isCarPlayAvailable {
//            // Protect against reentrancy.
//            if self.carPlayController == nil {
//                self.carPlayController = self.getCarPlayController()
//            }
//        } else {
//            self.carPlayController = nil
//        }
//
//        self.carPlayStatus.send(isCarPlayAvailable)
//        print("CARPLAY CONNECTED: \(isCarPlayAvailable)")
    }
}

extension PlaylistCarplayManager: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        attemptInterfaceConnection(isCarPlayAvailable: context.endpointAvailable)
    }
}
