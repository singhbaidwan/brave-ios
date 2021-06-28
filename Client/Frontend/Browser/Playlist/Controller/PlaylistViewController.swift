// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit
import BraveShared
import Shared
import AVKit
import AVFoundation
import CarPlay
import MediaPlayer
import SDWebImage
import CoreData
import Data

private let log = Logger.browserLogger

// MARK: PlaylistViewControllerDelegate
protocol PlaylistViewControllerDelegate: AnyObject {
    func onSidePanelStateChanged()
    func onFullscreen()
    func onExitFullscreen()
}

// MARK: PlaylistViewController

class PlaylistViewController: UIViewController, PlaylistViewControllerDelegate {
    
    // MARK: Properties

    private let player = MediaPlayer()
    private let playerView = VideoView()
    private let splitController = UISplitViewController()
    private let listController = PlaylistListViewController()
    private let detailController = PlaylistDetailViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overrideUserInterfaceStyle = .dark
        listController.delegate = self
        observePlayerStates()
        
        splitController.do {
            $0.viewControllers = [SettingsNavigationController(rootViewController: listController),
                                  SettingsNavigationController(rootViewController: detailController)]
            $0.delegate = self
            $0.primaryEdge = PlayListSide(rawValue: Preferences.Playlist.listViewSide.value) == .left ? .leading : .trailing
            $0.presentsWithGesture = false
            $0.maximumPrimaryColumnWidth = 400
            $0.minimumPrimaryColumnWidth = 400
        }
        
        addChild(splitController)
        view.addSubview(splitController.view)
        
        splitController.do {
            $0.didMove(toParent: self)
            $0.view.translatesAutoresizingMaskIntoConstraints = false
            $0.view.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
        }
        
        updateLayoutForOrientationChange()
        
        detailController.setVideoPlayer(playerView)
        detailController.navigationController?.setNavigationBarHidden(splitController.isCollapsed || traitCollection.horizontalSizeClass == .regular, animated: false)
        
        if UIDevice.isPhone {
            if splitController.isCollapsed == false && traitCollection.horizontalSizeClass == .regular {
                listController.updateLayoutForMode(.pad)
                detailController.updateLayoutForMode(.pad)
            } else {
                listController.updateLayoutForMode(.phone)
                detailController.updateLayoutForMode(.phone)
                
                // On iPhone Pro Max which displays like an iPad, we need to hide navigation bar.
                if UIDevice.isPhone && UIDevice.current.orientation.isLandscape {
                    listController.onFullScreen()
                }
            }
        } else {
            listController.updateLayoutForMode(.pad)
            detailController.updateLayoutForMode(.pad)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        updateLayoutForOrientationChange()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func updateLayoutForOrientationChange() {
        if playerView.isFullscreen {
            splitController.preferredDisplayMode = .secondaryOnly
        } else {
            if UIDevice.current.orientation.isLandscape {
                splitController.preferredDisplayMode = .secondaryOnly
            } else {
                splitController.preferredDisplayMode = .primaryOverlay
            }
        }
    }
    
    private func observePlayerStates() {
        player.publisher(for: .finishedPlaying).sink { [weak self] event in
            guard let self = self, let currentItem = event.mediaPlayer.currentItem else { return }
            
            self.playerView.controlsView.playPauseButton.isEnabled = false
            self.playerView.controlsView.playPauseButton.setImage(#imageLiteral(resourceName: "playlist_pause"), for: .normal)
            event.mediaPlayer.pause()
            
            let endTime = CMTimeConvertScale(currentItem.asset.duration, timescale: event.mediaPlayer.currentTime.timescale, method: .roundHalfAwayFromZero)
            
            self.playerView.controlsView.trackBar.setTimeRange(currentTime: currentItem.currentTime(), endTime: endTime)
            self.player.seek(to: .zero)
            
            self.playerView.controlsView.playPauseButton.isEnabled = true
            self.playerView.controlsView.playPauseButton.setImage(#imageLiteral(resourceName: "playlist_play"), for: .normal)

            self.playerView.toggleOverlays(showOverlay: true)
            self.onNextTrack(isUserInitiated: false)
        }
        
        player.publisher(for: .periodicPlayTimeChanged).sink { [weak self] event in
            guard let self = self, let currentItem = event.mediaPlayer.currentItem else { return }
            
            let endTime = CMTimeConvertScale(currentItem.asset.duration, timescale: event.mediaPlayer.currentTime.timescale, method: .roundHalfAwayFromZero)
            
            if CMTimeCompare(endTime, .zero) != 0 && endTime.value > 0 {
                self.playerView.controlsView.trackBar.setTimeRange(currentTime: event.mediaPlayer.currentTime, endTime: endTime)
            }
        }
        
        self.playerView.infoView.pictureInPictureButton.isEnabled =
            AVPictureInPictureController.isPictureInPictureSupported()
        player.publisher(for: .pictureInPictureStatusChanged).sink { [weak self] event in
            guard let self = self else { return }
            
            self.playerView.infoView.pictureInPictureButton.isEnabled =
                event.mediaPlayer.pictureInPictureController?.isPictureInPicturePossible == true
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension PlaylistViewController: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .fullScreen
    }
}

// MARK: - UISplitViewControllerDelegate

extension PlaylistViewController: UISplitViewControllerDelegate {
    func splitViewControllerSupportedInterfaceOrientations(_ splitViewController: UISplitViewController) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        
        // On iPhone, always display the iPhone layout (collapsed) no matter what.
        // On iPad, we need to update both the list controller's layout (collapsed) and the detail controller's layout (collapsed).
        listController.updateLayoutForMode(.phone)
        detailController.setVideoPlayer(nil)
        detailController.updateLayoutForMode(.phone)
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        
        // On iPhone, always display the iPad layout (expanded) when not in compact mode.
        // On iPad, we need to update both the list controller's layout (expanded) and the detail controller's layout (expanded).
        listController.updateLayoutForMode(.pad)
        detailController.setVideoPlayer(playerView)
        detailController.updateLayoutForMode(.pad)
        
        if UIDevice.isPhone {
            detailController.navigationController?.setNavigationBarHidden(true, animated: true)
        }
        
        return detailController.navigationController ?? detailController
    }
}

extension PlaylistViewController: VideoViewDelegate {
    func onPreviousTrack(isUserInitiated: Bool) {
        
    }
    
    func onNextTrack(isUserInitiated: Bool) {
        
    }
    
    func onSidePanelStateChanged() {
        detailController.onSidePanelStateChanged()
    }
    
    func onPictureInPicture() {
        guard let pictureInPictureController = player.pictureInPictureController else { return }
  
        DispatchQueue.main.async {
            if pictureInPictureController.isPictureInPictureActive {
                self.onPictureInPicture(enabled: false)
                pictureInPictureController.stopPictureInPicture()
            } else {
                if #available(iOS 14.0, *) {
                    pictureInPictureController.requiresLinearPlayback = false
                }

                self.onPictureInPicture(enabled: true)
                pictureInPictureController.startPictureInPicture()
            }
        }
    }
    
    func onFullscreen() {
        detailController.onFullScreen()
    }
    
    func onExitFullscreen() {
        detailController.onExitFullScreen()
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.stop()
    }
    
    func seekBackwards() {
        player.seekBackwards()
    }
    
    func seekForwards() {
        player.seekForwards()
    }
    
    func seek(to time: TimeInterval) {
        player.seek(to: time)
    }
    
    func seek(relativeOffset: Float) {
        if let currentItem = player.currentItem {
            let seekTime = CMTimeMakeWithSeconds(Float64(CGFloat(relativeOffset) * CGFloat(currentItem.asset.duration.value) / CGFloat(currentItem.asset.duration.timescale)), preferredTimescale: currentItem.currentTime().timescale)
            seek(to: seekTime.seconds)
        }
    }
    
    func setPlaybackRate(rate: Float) {
        player.setPlaybackRate(rate: rate)
    }
    
    func togglePlayerGravity() {
        player.toggleGravity()
    }
    
    func toggleRepeatMode() {
        player.toggleRepeatMode()
    }
    
    var isPlaying: Bool {
        player.isPlaying
    }
    
    var repeatMode: MediaPlayer.RepeatMode {
        player.repeatState
    }
    
    public func load(url: URL, autoPlayEnabled: Bool) {
        load(asset: AVURLAsset(url: url), autoPlayEnabled: autoPlayEnabled)
    }
    
    public func load(asset: AVURLAsset, autoPlayEnabled: Bool) {
        player.load(asset: asset)
        .receive(on: RunLoop.main)
        .sink(receiveCompletion: { error in
            if case .failure(let error) = error {
                print(error)
            }
        }, receiveValue: { [weak self] isNewItem in
            guard let self = self, let item = self.player.currentItem else { return }
            
            // We are playing the same item again..
            if !isNewItem {
                self.pause()
                self.seek(relativeOffset: 0.0) // Restart playback
                self.play()
                return
            }
            
            // Live media item
            let isPlayingLiveMedia = self.player.isLiveMedia
            self.playerView.controlsView.trackBar.isUserInteractionEnabled = !isPlayingLiveMedia
            self.playerView.controlsView.skipBackButton.isEnabled = !isPlayingLiveMedia
            self.playerView.controlsView.skipForwardButton.isEnabled = !isPlayingLiveMedia
            
            // Track-bar
            let endTime = CMTimeConvertScale(item.asset.duration, timescale: self.player.currentTime.timescale, method: .roundHalfAwayFromZero)
            self.playerView.controlsView.trackBar.setTimeRange(currentTime: item.currentTime(), endTime: endTime)
            
            if autoPlayEnabled {
                self.play() // Play the new item
            }
        })
    }
}

/*

// MARK: - CarPlay Delegate
extension ListController: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        // This only ever shows "Connected" in an actual car. The simulator is no good.
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
            ensureMainThreadSync {
                let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item)
                self.contentManager.nowPlayingIdentifiers = [mediaItem.name]

                mediaInfo.loadMediaItem(mediaItem, index: indexPath.item) { error in
                    switch error {
                    case .none:
                        MPNowPlayingInfoCenter.default().playbackState = .playing
                        completionHandler(nil)
                    case .expired:
                        MPNowPlayingInfoCenter.default().playbackState = .stopped
                        completionHandler(Strings.PlayList.expiredAlertDescription)
                    case .error(let error):
                        MPNowPlayingInfoCenter.default().playbackState = .stopped
                        completionHandler(error)
                    }
                }
            }
        } else {
            // Tab Section
            completionHandler(nil)
        }
        
        // Workaround to see carplay NowPlaying on the simulator
        #if targetEnvironment(simulator)
        ensureMainThreadSync {
            UIApplication.shared.endReceivingRemoteControlEvents()
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif
    }
    
    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}

extension ListController: MPPlayableContentDataSource {
    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == 0 {
            return 1 // 1 Tab.
        }
        
        return ensureMainThreadSync {
            return PlaylistManager.shared.numberOfAssets
        }
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
            return ensureMainThreadSync {
                let mediaItem = PlaylistManager.shared.itemAtIndex(indexPath.item)
                let cacheState = PlaylistManager.shared.state(for: mediaItem.pageSrc)
                let item = MPContentItem(identifier: mediaItem.name)
                item.title = mediaItem.name
                item.subtitle = mediaItem.pageSrc
                item.isPlayable = true
                item.isStreamingContent = cacheState != .downloaded
                loadThumbnail(item: mediaItem, contentItem: item)
                return item
            }
        }
        
        return nil
    }
}
*/
