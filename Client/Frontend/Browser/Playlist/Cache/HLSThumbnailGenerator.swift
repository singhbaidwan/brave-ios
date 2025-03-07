// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import AVFoundation
import CoreImage
import SDWebImage

public class HLSThumbnailGenerator {
    private enum State {
        case loading
        case ready
        case failed
    }

    private let asset: AVAsset
    private let sourceURL: URL
    private let player: AVPlayer?
    private let videoOutput: AVPlayerItemVideoOutput?
    private var observer: NSKeyValueObservation?
    private var state: State = .loading
    private let queue = DispatchQueue(label: "com.brave.hls-thumbnail-generator")
    private let completion: (UIImage?, Error?) -> Void

    init(url: URL, time: TimeInterval, completion: @escaping (UIImage?, Error?) -> Void) {
        self.asset = AVAsset(url: url)
        self.sourceURL = url
        self.completion = completion

        let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [])
        self.player = AVPlayer(playerItem: item).then {
            $0.rate = 0
        }
        
        self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        
        self.observer = self.player?.currentItem?.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            
            if item.status == .readyToPlay && self.state == .loading {
                self.state = .ready
                self.generateThumbnail(at: time)
            } else if item.status == .failed {
                self.state = .failed
                DispatchQueue.main.async {
                    self.completion(nil, "Failed to load item")
                }
            }
        }
        
        if let videoOutput = self.videoOutput {
            self.player?.currentItem?.add(videoOutput)
        }
    }

    private func generateThumbnail(at time: TimeInterval) {
        queue.async {
            let time = CMTime(seconds: time, preferredTimescale: 1)
            self.player?.seek(to: time) { [weak self] finished in
                guard let self = self else { return }
                
                if finished {
                    self.queue.async {
                        if let buffer = self.videoOutput?.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
                            self.snapshotPixelBuffer(buffer, atTime: time.seconds)
                        } else {
                            DispatchQueue.main.async {
                                self.completion(nil, "Cannot copy pixel-buffer (PBO)")
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.completion(nil, "Failed to seek to specified time")
                    }
                }
            }
        }
    }

    private func snapshotPixelBuffer(_ buffer: CVPixelBuffer, atTime time: TimeInterval) {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let quartzFrame = CGRect(x: 0, y: 0,
                                 width: CVPixelBufferGetWidth(buffer),
                                 height: CVPixelBufferGetHeight(buffer))
        
        if let cgImage = CIContext().createCGImage(ciImage, from: quartzFrame) {
            let result = UIImage(cgImage: cgImage)
            
            DispatchQueue.main.async {
                self.completion(result, nil)
            }
        } else {
            DispatchQueue.main.async {
                self.completion(nil, "Failed to create image from pixel-buffer frame.")
            }
        }
    }

}
