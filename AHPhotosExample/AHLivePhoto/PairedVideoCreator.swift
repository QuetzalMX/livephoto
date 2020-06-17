//
//  PairedVideoCreator.swift
//  Amazing Humans
//
//  Created by Fernando Olivares on 02/05/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import Foundation
import AVKit
import Photos

class PairedVideoCreator {
	
	init(inputURL: URL, outputURL: URL, identifier: String) throws {
		metadataIdentifier = identifier
		asset = AVAsset(url: inputURL)
		writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
		reader = try AVAssetReader(asset: asset)
	}
	
	enum RewriteError : Error {
		case loadingTracks(Error)
		case reading(Error?)
		case videoWriting(Error?)
		case audioWriting(Error?)
	}
	
	func rewriteVideo(completion: @escaping (RewriteError?) -> Void) {
		
		let videoTrack: AVAssetTrack
		let videoEstimatedFrameCount: Int
		let possibleAudioTrack: AVAssetTrack?
		
		// Are the tracks ready to be processed?
		switch tracks {
			
		case .unloaded:
			loadTracks { result in
				switch result {
					
				case .success:
					self.rewriteVideo(completion: completion)
					
				case .failure(let error):
					completion(.loadingTracks(error))
				}
			}
			return
			
		case .failedLoading(let error):
			completion(.loadingTracks(error))
			return
			
		case .loaded(let loadedVideoTrack, let loadedFrameEstimation, let possibleLoadedAudioTrack):
			videoTrack = loadedVideoTrack
			videoEstimatedFrameCount = loadedFrameEstimation
			possibleAudioTrack = possibleLoadedAudioTrack
		}
		
		// Ready to be processed.
		// We'll be pairing the new video to a photo with the given identifier.
		let visualCopier = VisualAssetCopier(track: videoTrack)
		writer.add(visualCopier.writer)
		add(visualCopier)
		
		let audioCopier = AssetCopier(track: possibleAudioTrack, mediaType: .audio)
		writer.add(audioCopier.writer)
		add(audioCopier)

		let metadataCopier = MetadataCopier(sharedAssetIdentifier: metadataIdentifier,
											duration: asset.duration,
											estimatedFrameCount: videoEstimatedFrameCount)
		writer.metadata = [metadataCopier.metadata]
		writer.add(metadataCopier.writer.assetWriterInput)
		
		// Begin.
		writer.startWriting()
        writer.startSession(atSourceTime: .zero)

		metadataCopier.copy()
		
		guard reader.startReading() else {
			completion(.reading(reader.error))
			writer.cancelWriting()
			return
		}
		
		audioCopier.copy {
			
			visualCopier.copy {
								
				guard self.reader.error == nil else {
					completion(.videoWriting(self.reader.error!))
					return
				}
				
				self.writer.finishWriting {
					completion(nil)
				}
			}
		}
	}
	
	private let metadataIdentifier: String
	private let asset: AVAsset
	private let writer: AVAssetWriter
	private let reader: AVAssetReader
	private var tracks: TrackStatus = .unloaded
}

extension PairedVideoCreator {
	
	private enum TrackStatus {
		case unloaded
		case loaded(video: AVAssetTrack, videoEstimatedFrameCount: Int, audio: AVAssetTrack?)
		case failedLoading(Error)
	}
	
	private enum LoadTrackFailed : Error {
		case cancelled
		case busy
		case notFound
		case empty
		case loading(Error?)
		case unknown(Error?)
	}

	private func loadTracks(completion: @escaping (Result<Void, LoadTrackFailed>) -> Void) {
	
		// As per the documentation, you should never access tracks on iOS without loading them asynchronously.
		asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
			
			// Could we load the tracks?
			var error: NSError? = nil
			switch self.asset.statusOfValue(forKey: "tracks", error: &error) {
				
			case .cancelled:
				completion(.failure(.cancelled))
				return
				
			case .failed:
				completion(.failure(.loading(error)))
				return
				
			case .loading:
				completion(.failure(.busy))
				return
				
			case .loaded:
				break
				
			default:
				completion(.failure(.unknown(error)))
				return
			}
			
			// We could. Is there at least 1 video track?
			guard let videoTrack = self.asset.tracks(withMediaType: .video).first else {
				completion(.failure(.notFound))
				return
			}
			
			// There is. Is it empty?
			let estimatedFrameCount = Int(CMTimeGetSeconds(self.asset.duration) * Float64(videoTrack.nominalFrameRate))
			guard estimatedFrameCount > 0 else {
				completion(.failure(.empty))
				return
			}
			
			
			// It has content. Do we have an audio track?
			var possibleAudioTrack: AVAssetTrack?
			if let audioTrack = self.asset.tracks(withMediaType: .audio).first {
				possibleAudioTrack = audioTrack
			}
			
			self.tracks = .loaded(video: videoTrack,
								  videoEstimatedFrameCount: estimatedFrameCount,
								  audio: possibleAudioTrack)
			completion(.success(()))
		}
	}
	
	private func add(_ assetCopier: AssetCopier?) {
		
		guard let assetCopier = assetCopier, let assetCopierReader = assetCopier.reader else { return }

		reader.add(assetCopierReader)
	}
}
