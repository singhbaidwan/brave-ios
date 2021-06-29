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

class PlaylistMediaInfo: NSObject {
    private weak var playerView: VideoView?
    private var webLoader: PlaylistWebLoader?
    private var playerStatusObserver: PlaylistPlayerStatusObserver?
    private var rateObserver: NSKeyValueObservation?
    public var nowPlayingInfo: PlaylistInfo? {
        didSet {
            updateNowPlayingMediaInfo()
        }
    }
    
    public init(playerView: VideoView) {
        self.playerView = playerView
        super.init()
        
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        updateNowPlayingMediaInfo()
        rateObserver = playerView.player.observe(\AVPlayer.rate, changeHandler: { [weak self] _, _ in
            self?.updateNowPlayingMediaInfo()
        })
    }
    
    deinit {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        self.webLoader?.removeFromSuperview()
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    func updateNowPlayingMediaInfo() {
        if let nowPlayingItem = self.nowPlayingInfo {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPNowPlayingInfoPropertyMediaType: "Audio",
                MPMediaItemPropertyTitle: nowPlayingItem.name,
                MPMediaItemPropertyArtist: URL(string: nowPlayingItem.pageSrc)?.baseDomain ?? nowPlayingItem.pageSrc,
                MPMediaItemPropertyPlaybackDuration: TimeInterval(nowPlayingItem.duration),
                MPNowPlayingInfoPropertyPlaybackRate: Double(self.playerView?.player.rate ?? 1.0),
                MPNowPlayingInfoPropertyPlaybackProgress: Float(0.0),
                MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(self.playerView?.player.currentTime().seconds ?? 0.0)
            ]
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    
    func updateNowPlayingMediaArtwork(image: UIImage?) {
        if let image = image {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                // Do not resize image here.
                // According to Apple it isn't necessary to use expensive resize operations
                return image
            })
        }
    }
}

extension PlaylistMediaInfo: MPPlayableContentDelegate {
    
    enum MediaPlaybackError {
        case expired
        case error(Error)
        case none
    }
    
    func loadMediaItem(_ item: PlaylistInfo, index: Int, autoPlayEnabled: Bool = true, completion: @escaping (MediaPlaybackError) -> Void) {
        self.nowPlayingInfo = item
        self.playerStatusObserver = nil
        self.playerView?.stop()
        let cacheState = PlaylistManager.shared.state(for: item.pageSrc)

        if cacheState == .invalid {
            // Fallback to web stream
            let streamingFallback = { [weak self] in
                guard let self = self else {
                    completion(.expired)
                    return
                }
                
                self.webLoader?.removeFromSuperview()
                self.webLoader = PlaylistWebLoader(handler: { [weak self] newItem in
                    guard let self = self else { return }
                    defer {
                        // Destroy the web loader when the callback is complete.
                        self.webLoader?.removeFromSuperview()
                        self.webLoader = nil
                    }
                    
                    if let newItem = newItem, let url = URL(string: newItem.src) {
                        self.playerView?.load(url: url, resourceDelegate: nil, autoPlayEnabled: autoPlayEnabled)

                        PlaylistItem.updateItem(newItem) {
                            completion(.none)
                        }
                    } else {
                        self.nowPlayingInfo = nil
                        self.updateNowPlayingMediaArtwork(image: nil)
                        completion(.expired)
                    }
                }).then {
                    // If we don't do this, youtube shows ads 100% of the time.
                    // It's some weird race-condition in WKWebView where the content blockers may not load until
                    // The WebView is visible!
                    self.playerView?.window?.insertSubview($0, at: 0)
                }
                
                if let url = URL(string: item.pageSrc) {
                    self.webLoader?.load(url: url)
                } else {
                    self.nowPlayingInfo = nil
                    self.updateNowPlayingMediaArtwork(image: nil)
                    completion(.error("Cannot Load Media"))
                }
            }

            // Determine if an item can be streamed and stream it directly
            if !item.src.isEmpty, let url = URL(string: item.src) {
                // Try to stream the asset from its url..
                MediaResourceManager.canStreamURL(url) { [weak self] canStream in
                    guard let self = self else { return }
                    
                    if canStream {
                        self.playerView?.seek(to: 0.0)
                        self.playerView?.load(url: url, resourceDelegate: nil, autoPlayEnabled: autoPlayEnabled)
                        
                        if let player = self.playerView?.player {
                            self.playerStatusObserver = PlaylistPlayerStatusObserver(player: player, onStatusChanged: { status in
                                self.playerStatusObserver = nil

                                DispatchQueue.main.async {
                                    if status == .failed {
                                        self.nowPlayingInfo = nil
                                        self.updateNowPlayingMediaArtwork(image: nil)
                                        completion(.expired)
                                    } else {
                                        completion(.none)
                                    }
                                }
                            })
                        } else {
                            self.nowPlayingInfo = nil
                            self.updateNowPlayingMediaArtwork(image: nil)
                            completion(.expired)
                        }
                    } else {
                        // Stream failed so fallback to the webview
                        // It's possible the URL expired..
                        streamingFallback()
                    }
                }
            } else {
                // Fallback to the webview because there was no stream URL somehow..
                streamingFallback()
            }
        } else {
            // Load from the cache since this item was downloaded before..
            if let asset = PlaylistManager.shared.assetAtIndex(index) {
                self.playerView?.load(asset: asset, autoPlayEnabled: autoPlayEnabled)
                completion(.none)
            } else {
                completion(.expired)
            }
        }
    }
}

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

extension MediaResourceManager {
    
    // Would be nice if AVPlayer could detect the mime-type from the URL for my delegate without a head request..
    // This function only exists because I can't figure out why videos from URLs don't play unless I explicitly specify a mime-type..
    static func canStreamURL(_ url: URL, _ completion: @escaping (Bool) -> Void) {
        switch Reach().connectionStatus() {
        case .offline, .unknown:
            completion(false)
            return
        case .online:
            break
        }
        
        getMimeType(url) { mimeType in
            if let mimeType = mimeType {
                completion(!mimeType.isEmpty)
            } else {
                completion(false)
            }
        }
    }
    
    static func getMimeType(_ url: URL, _ completion: @escaping (String?) -> Void) {
        let request: URLRequest = {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
            
            // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range
            request.addValue("bytes=0-1", forHTTPHeaderField: "Range")
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Playback-Session-Id")
            request.addValue(UserAgent.shouldUseDesktopMode ? UserAgent.desktop : UserAgent.mobile, forHTTPHeaderField: "User-Agent")
            return request
        }()
        
        URLSession(configuration: .ephemeral).dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    log.error("Error fetching MimeType for playlist item: \(url) - \(error)")
                    return completion(nil)
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode == 302 || response.statusCode >= 200 && response.statusCode <= 299 {
                    if let contentType = response.allHeaderFields["Content-Type"] as? String {
                        completion(contentType)
                        return
                    } else {
                        completion("video/*")
                        return
                    }
                }
                
                completion(nil)
            }
        }.resume()
    }
}
