// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Combine
import CarPlay
import MediaPlayer
import Data
import Shared

private let log = Logger.browserLogger

class PlaylistCarplayController: NSObject {
    private let player: MediaPlayer
    private let mediaStreamer: PlaylistMediaStreamer
    private let contentManager: MPPlayableContentManager
    private var playerStateObservers = Set<AnyCancellable>()
    private var assetStateObservers = Set<AnyCancellable>()
    private var assetLoadingStateObservers = Set<AnyCancellable>()
    private var playlistItemIds = [String]()
    
    init(player: MediaPlayer, contentManager: MPPlayableContentManager) {
        self.player = player
        self.contentManager = contentManager
        self.mediaStreamer = PlaylistMediaStreamer(playerView: (UIApplication.shared.delegate as? AppDelegate)?.window ?? UIView())
        super.init()
        
        observePlayerStates()
        PlaylistManager.shared.reloadData()
        
        playlistItemIds = (0..<PlaylistManager.shared.numberOfAssets).map({
            PlaylistManager.shared.itemAtIndex($0)?.pageSrc ?? UUID().uuidString
        })
        
        contentManager.dataSource = self
        contentManager.delegate = self
        contentManager.reloadData()
        
        // Workaround to see carplay NowPlaying on the simulator
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            UIApplication.shared.endReceivingRemoteControlEvents()
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif
    }
    
    func observePlayerStates() {
        player.publisher(for: .play).sink { _ in
            MPNowPlayingInfoCenter.default().playbackState = .playing
        }.store(in: &playerStateObservers)
        
        player.publisher(for: .pause).sink { _ in
            MPNowPlayingInfoCenter.default().playbackState = .paused
        }.store(in: &playerStateObservers)
        
        player.publisher(for: .stop).sink { _ in
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }.store(in: &playerStateObservers)
        
        player.publisher(for: .changePlaybackRate).sink { [weak self] _ in
            guard let self = self else { return }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
        }.store(in: &playerStateObservers)
        
        player.publisher(for: .finishedPlaying).sink { [weak self] event in
            guard let self = self,
                  let currentItem = event.mediaPlayer.currentItem else { return }
            
            event.mediaPlayer.pause()
            self.player.seek(to: .zero)
            //self.onNextTrack(self.playerView, isUserInitiated: false)
        }.store(in: &playerStateObservers)
    }
}

extension PlaylistCarplayController: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        
        PlaylistCarplayManager.shared.attemptInterfaceConnection(isCarPlayAvailable: context.endpointAvailable)
    }
    
    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        
        if indexPath.count == 2 {
            // Item Section
            DispatchQueue.main.async {
                guard let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item) else {
                    completionHandler(nil)
                    return
                }
                
                self.contentManager.nowPlayingIdentifiers = [mediaItem.name]
                self.playItem(item: mediaItem) { error in
                    switch error {
                    case .other(let error):
                        log.error(error)
                        completionHandler("Unknown Error")
                    case .expired:
                        completionHandler(Strings.PlayList.expiredAlertDescription)
                    case .none:
                        completionHandler(nil)
                    case .cancelled:
                        log.debug("User Cancelled Playlist playback")
                        completionHandler(nil)
                    }
                    
                    // Workaround to see carplay NowPlaying on the simulator
                    #if targetEnvironment(simulator)
                    DispatchQueue.main.async {
                        UIApplication.shared.endReceivingRemoteControlEvents()
                        UIApplication.shared.beginReceivingRemoteControlEvents()
                    }
                    #endif
                }
            }
        } else {
            // Tab Section
            completionHandler(nil)
        }
    }
    
    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
        contentManager.reloadData()
    }
}

extension PlaylistCarplayController: MPPlayableContentDataSource {
    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == 0 {
            return 1 // 1 Tab.
        }
        
        return playlistItemIds.count
    }
    
    func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
        true
    }
    
    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        // Tab Section
        if indexPath.count == 1 {
            let item = MPContentItem(identifier: "BravePlaylist")
            item.title = "Brave Playlist"
            item.isContainer = true
            item.isPlayable = false
            let imageIcon = #imageLiteral(resourceName: "settings-shields")
            item.artwork = MPMediaItemArtwork(boundsSize: imageIcon.size, requestHandler: { _ -> UIImage in
                return imageIcon
            })
            return item
        }

        if indexPath.count == 2 {
            // Items section
            guard let itemId = playlistItemIds[safe: indexPath.row] else {
                return nil
            }
            
            let item = MPContentItem(identifier: itemId)
            
            DispatchQueue.main.async {
                guard let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item) else {
                    return
                }

                let cacheState = PlaylistManager.shared.state(for: mediaItem.pageSrc)
                item.title = mediaItem.name
                item.subtitle = mediaItem.pageSrc
                item.isPlayable = true
                item.isStreamingContent = cacheState != .downloaded
                item.loadThumbnail(for: mediaItem)
            }
            return item
        }

        return nil
    }
}

extension PlaylistCarplayController {
    private func play() {
        player.play()
    }
    
    private func pause() {
        player.pause()
    }
    
    private func stop() {
        player.stop()
    }
    
    private func seekBackwards(_ videoView: VideoView) {
        player.seekBackwards()
    }
    
    private func seekForwards(_ videoView: VideoView) {
        player.seekForwards()
    }
    
    private func seek(to time: TimeInterval) {
        player.seek(to: time)
    }
    
    func seek(relativeOffset: Float) {
        if let currentItem = player.currentItem {
            let seekTime = CMTimeMakeWithSeconds(Float64(CGFloat(relativeOffset) * CGFloat(currentItem.asset.duration.value) / CGFloat(currentItem.asset.duration.timescale)), preferredTimescale: currentItem.currentTime().timescale)
            seek(to: seekTime.seconds)
        }
    }
    
    func load(url: URL, autoPlayEnabled: Bool) -> AnyPublisher<Void, Error> {
        load(asset: AVURLAsset(url: url), autoPlayEnabled: autoPlayEnabled)
    }
    
    func load(asset: AVURLAsset, autoPlayEnabled: Bool) -> AnyPublisher<Void, Error> {
        assetLoadingStateObservers.removeAll()
        player.stop()
        
        return Future { [weak self] resolver in
            guard let self = self else {
                resolver(.failure("User Cancelled Playback"))
                return
            }
            
            self.player.load(asset: asset)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { error in
                if case .failure(let error) = error {
                    resolver(.failure(error))
                }
            }, receiveValue: { [weak self] isNewItem in
                guard let self = self else {
                    resolver(.failure("User Cancelled Playback"))
                    return
                }
                
                guard self.player.currentItem != nil else {
                    resolver(.failure("Couldn't load playlist item"))
                    return
                }
                
                // We are playing the same item again..
                if !isNewItem {
                    self.pause()
                    self.seek(relativeOffset: 0.0) // Restart playback
                    self.play()
                    resolver(.success(Void()))
                    return
                }
                
                // Track-bar
                if autoPlayEnabled {
                    resolver(.success(Void()))
                    self.play() // Play the new item
                }
            }).store(in: &self.assetLoadingStateObservers)
        }.eraseToAnyPublisher()
    }
    
    func playItem(item: PlaylistInfo, completion: ((PlaylistMediaStreamer.PlaybackError) -> Void)?) {
        assetLoadingStateObservers.removeAll()
        assetStateObservers.removeAll()

        // If the item is cached, load it from the cache and play it.
        let cacheState = PlaylistManager.shared.state(for: item.pageSrc)
        if cacheState != .invalid {
            if let index = PlaylistManager.shared.index(of: item.pageSrc),
               let asset = PlaylistManager.shared.assetAtIndex(index) {
                load(asset: asset, autoPlayEnabled: true)
                .handleEvents(receiveCancel: {
                    PlaylistMediaStreamer.clearNowPlayingInfo()
                    completion?(.cancelled)
                })
                .sink(receiveCompletion: { error in
                    switch error {
                    case .failure(let error):
                        PlaylistMediaStreamer.clearNowPlayingInfo()
                        completion?(.other(error))
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] _ in
                    guard let self = self else {
                        PlaylistMediaStreamer.clearNowPlayingInfo()
                        completion?(.cancelled)
                        return
                    }
                    
                    PlaylistMediaStreamer.setNowPlayingInfo(item, withPlayer: self.player)
                    completion?(.none)
                }).store(in: &assetLoadingStateObservers)
            } else {
                completion?(.expired)
            }
            return
        }
        
        // The item is not cached so we should attempt to stream it
        mediaStreamer.loadMediaStreamingAsset(item)
        .handleEvents(receiveCancel: {
            PlaylistMediaStreamer.clearNowPlayingInfo()
            completion?(.cancelled)
        })
        .sink(receiveCompletion: { error in
            switch error {
            case .failure(let error):
                PlaylistMediaStreamer.clearNowPlayingInfo()
                completion?(error)
            case .finished:
                break
            }
        }, receiveValue: { [weak self] _ in
            guard let self = self else {
                PlaylistMediaStreamer.clearNowPlayingInfo()
                completion?(.cancelled)
                return
            }
            
            // Item can be streamed, so let's retrieve its URL from our DB
            guard let index = PlaylistManager.shared.index(of: item.pageSrc),
                  let item = PlaylistManager.shared.itemAtIndex(index) else {
                PlaylistMediaStreamer.clearNowPlayingInfo()
                completion?(.expired)
                return
            }
            
            // Attempt to play the stream
            if let url = URL(string: item.pageSrc) {
                self.load(url: url, autoPlayEnabled: true)
                .handleEvents(receiveCancel: {
                    PlaylistMediaStreamer.clearNowPlayingInfo()
                    completion?(.cancelled)
                })
                .sink(receiveCompletion: { error in
                    switch error {
                    case .failure(let error):
                        PlaylistMediaStreamer.clearNowPlayingInfo()
                        completion?(.other(error))
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] _ in
                    guard let self = self else {
                        PlaylistMediaStreamer.clearNowPlayingInfo()
                        completion?(.cancelled)
                        return
                    }
                    
                    PlaylistMediaStreamer.setNowPlayingInfo(item, withPlayer: self.player)
                    completion?(.none)
                }).store(in: &self.assetLoadingStateObservers)
                log.debug("Playing Live Video: \(self.player.isLiveMedia)")
            } else {
                PlaylistMediaStreamer.clearNowPlayingInfo()
                completion?(.expired)
            }
        }).store(in: &assetStateObservers)
    }
}

extension MPContentItem {
    
    func loadThumbnail(for mediaItem: PlaylistInfo) {
        if thumbnailRenderer != nil {
            return
        }
        
        guard let assetUrl = URL(string: mediaItem.src),
              let favIconUrl = URL(string: mediaItem.pageSrc) else {
            return
        }
        
        thumbnailRenderer = PlaylistThumbnailRenderer()
        thumbnailRenderer?.loadThumbnail(assetUrl: assetUrl,
                                         favIconUrl: favIconUrl,
                                         completion: { [weak self] image in
                                            guard let self = self else { return }
                                            
                                            let image = image ?? #imageLiteral(resourceName: "settings-shields")
                                            self.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                                                return image
                                            })
                                         })
    }
    
    private struct AssociatedKeys {
        static var thumbnailRenderer: Int = 0
    }
    
    private var thumbnailRenderer: PlaylistThumbnailRenderer? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.thumbnailRenderer) as? PlaylistThumbnailRenderer }
        set { objc_setAssociatedObject(self, &AssociatedKeys.thumbnailRenderer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
