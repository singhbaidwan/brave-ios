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
    private let contentManager = MPPlayableContentManager.shared()
    private var assetStateObserver = Set<AnyCancellable>()
    
    init(player: MediaPlayer) {
        self.player = player
        self.mediaStreamer = PlaylistMediaStreamer(playerView: (UIApplication.shared.delegate as? AppDelegate)?.window ?? UIView())
        super.init()
    }
}

extension PlaylistCarplayController: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        
        if context.endpointAvailable || AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType == .carAudio {
            // CarPlay
            print("CAR PLAY CONNECTED")
        } else {
            print("CAR PLAY DISCONNECTED")
        }
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
                        MPNowPlayingInfoCenter.default().playbackState = .playing
                        //TODO: Something
                        completionHandler(nil)
                    case .cancelled:
                        log.debug("User Cancelled Playlist playback")
                        completionHandler(nil)
                    }
                }
            }
        } else {
            // Tab Section
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
    
    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}

extension PlaylistCarplayController: MPPlayableContentDataSource {
    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == 0 {
            return 1 // 1 Tab.
        }
        
        return PlaylistManager.shared.numberOfAssets
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
            guard let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item) else {
                return nil
            }
            
            let cacheState = PlaylistManager.shared.state(for: mediaItem.pageSrc)
            let item = MPContentItem(identifier: mediaItem.name)
            item.title = mediaItem.name
            item.subtitle = mediaItem.pageSrc
            item.isPlayable = true
            item.isStreamingContent = cacheState != .downloaded
            item.loadThumbnail(for: mediaItem)
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
        assetStateObserver.removeAll()
        player.stop()
        
        return Future { [weak self] resolver in
            guard let self = self else {
                resolver(.failure("User Cancelled Playback"))
                return
            }
            
            self.player.load(asset: asset)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] error in
                if case .failure(let error) = error {
                    self?.assetStateObserver.removeAll()
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
                
                self.assetStateObserver.removeAll()
                
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
            }).store(in: &self.assetStateObserver)
        }.eraseToAnyPublisher()
    }
    
    func playItem(item: PlaylistInfo, completion: ((PlaylistMediaStreamer.PlaybackError) -> Void)?) {
        self.assetStateObserver.forEach({ $0.cancel() })
        self.assetStateObserver.removeAll()
        
        // This MUST be checked.
        // The user must not be able to alter a player that isn't visible from any UI!
        // This is because, if car-play is interface is attached, the player can only be
        // controller through this UI so long as it is attached to it.
        // If it isn't attached, the player can only be controlled through the car-play interface.
        guard player.isAttachedToDisplay else {
            completion?(.none)
            return
        }

        // If the item is cached, load it from the cache and play it.
        let cacheState = PlaylistManager.shared.state(for: item.pageSrc)
        if cacheState != .invalid {
            if let index = PlaylistManager.shared.index(of: item.pageSrc),
               let asset = PlaylistManager.shared.assetAtIndex(index) {
                load(asset: asset, autoPlayEnabled: true)
                .handleEvents(receiveCancel: {
                    completion?(.cancelled)
                })
                .sink(receiveCompletion: { [weak self] error in
                    self?.assetStateObserver.removeAll()
                    switch error {
                    case .failure(let error):
                        completion?(.other(error))
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] _ in
                    self?.assetStateObserver.removeAll()
                    completion?(.none)
                }).store(in: &assetStateObserver)
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
        .sink(receiveCompletion: { [weak self] error in
            switch error {
            case .failure(let error):
                PlaylistMediaStreamer.clearNowPlayingInfo()
                self?.assetStateObserver.removeAll()
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
            
            self.assetStateObserver.removeAll()
            
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
                .sink(receiveCompletion: { [weak self] error in
                    self?.assetStateObserver.removeAll()
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
                        return
                    }
                    
                    self.assetStateObserver.removeAll()
                    PlaylistMediaStreamer.setNowPlayingInfo(item, withPlayer: self.player)
                    completion?(.none)
                }).store(in: &self.assetStateObserver)
                log.debug("Playing Live Video: \(self.player.isLiveMedia)")
            } else {
                PlaylistMediaStreamer.clearNowPlayingInfo()
                completion?(.expired)
            }
        }).store(in: &assetStateObserver)
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
        set { objc_setAssociatedObject(self, &AssociatedKeys.thumbnailRenderer, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
}
