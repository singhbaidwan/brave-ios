// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import CarPlay
import MediaPlayer
import Data

//class PlaylistCarplayController: NSObject {
//    private let contentManager = MPPlayableContentManager.shared()
//    
//}
//
//extension PlaylistCarplayController: MPPlayableContentDelegate {
//    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
//        
//        if context.endpointAvailable || AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType == .carAudio {
//            // CarPlay
//            print("CAR PLAY CONNECTED")
//        } else {
//            print("CAR PLAY DISCONNECTED")
//        }
//    }
//    
//    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
//        
//        if indexPath.count == 2 {
//            // Item Section
//            DispatchQueue.main.async {
//                let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item)
//                self.contentManager.nowPlayingIdentifiers = [mediaItem.name]
//
//                mediaInfo.loadMediaItem(mediaItem, index: indexPath.item) { error in
//                    switch error {
//                    case .none:
//                        MPNowPlayingInfoCenter.default().playbackState = .playing
//                        completionHandler(nil)
//                    case .expired:
//                        MPNowPlayingInfoCenter.default().playbackState = .stopped
//                        completionHandler(Strings.PlayList.expiredAlertDescription)
//                    case .error(let error):
//                        MPNowPlayingInfoCenter.default().playbackState = .stopped
//                        completionHandler(error)
//                    }
//                }
//            }
//        } else {
//            // Tab Section
//            completionHandler(nil)
//        }
//        
//        // Workaround to see carplay NowPlaying on the simulator
//        #if targetEnvironment(simulator)
//        DispatchQueue.main.async {
//            UIApplication.shared.endReceivingRemoteControlEvents()
//            UIApplication.shared.beginReceivingRemoteControlEvents()
//        }
//        #endif
//    }
//    
//    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
//        completionHandler(nil)
//    }
//}
//
//extension PlaylistCarplayController: MPPlayableContentDataSource {
//    func numberOfChildItems(at indexPath: IndexPath) -> Int {
//        if indexPath.indices.count == 0 {
//            return 1 // 1 Tab.
//        }
//        
//        return ensureMainThreadSync {
//            return PlaylistManager.shared.numberOfAssets
//        }
//    }
//    
//    func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
//        true
//    }
//    
//    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
//        // Tab Section
//        if indexPath.count == 1 {
//            let item = MPContentItem(identifier: "BravePlaylist")
//            item.title = "Brave Playlist"
//            item.isContainer = true
//            item.isPlayable = false
//            let imageIcon = #imageLiteral(resourceName: "settings-shields")
//            item.artwork = MPMediaItemArtwork(boundsSize: imageIcon.size, requestHandler: { _ -> UIImage in
//                return imageIcon
//            })
//            return item
//        }
//        
//        if indexPath.count == 2 {
//            // Items section
//            return ensureMainThreadSync {
//                let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item)
//                let cacheState = PlaylistManager.shared.state(for: mediaItem.pageSrc)
//                let item = MPContentItem(identifier: mediaItem.name)
//                item.title = mediaItem.name
//                item.subtitle = mediaItem.pageSrc
//                item.isPlayable = true
//                item.isStreamingContent = cacheState != .downloaded
//                loadThumbnail(item: mediaItem, contentItem: item)
//                return item
//            }
//        }
//        
//        return nil
//    }
//}
