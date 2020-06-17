//
//  AmazingAssetCopiers.swift
//  Amazing Humans
//
//  Created by Fernando Olivares on 02/05/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import Foundation
import AVKit
import Photos

class AssetCopier {
	
	let writer: AVAssetWriterInput
	let reader: AVAssetReaderTrackOutput?
	
	init(track: AVAssetTrack?,
		 mediaType: AVMediaType,
		 writerOutputSettings: [String : Any]? = nil,
		 readerOutputSettings: [String : Any]? = nil) {
		
		writer = AVAssetWriterInput(mediaType: mediaType, outputSettings: writerOutputSettings)
		if let existingTrack = track {
			reader = AVAssetReaderTrackOutput(track: existingTrack, outputSettings: readerOutputSettings)
		} else {
			reader = nil
		}
	}
	
	func copy(completion: @escaping () -> Void) {
		
		guard let reader = reader else {
			// If we were not given a track, consider the copy done.
			self.writer.markAsFinished()
			completion()
			return
		}
		
		writer.requestMediaDataWhenReady(on: DispatchQueue(label: String(describing: self))) {
			
			while self.writer.isReadyForMoreMediaData {
				
				if let sampleBuffer = reader.copyNextSampleBuffer() {
				
					guard self.writer.append(sampleBuffer) else {
						continue
					}
					
				} else {
					self.writer.markAsFinished()
					completion()
				}
			}
		}
	}
}

class VisualAssetCopier : AssetCopier {
	
	init(track: AVAssetTrack) {
		
		let writerOutputSettings: [String : Any] = [
			AVVideoCodecKey : AVVideoCodecType.h264,
			AVVideoWidthKey : track.naturalSize.width,
			AVVideoHeightKey : track.naturalSize.height
		]
		
		let readerOutputSettings = [
			kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)
		]
		
		super.init(track: track,
				   mediaType: .video,
				   writerOutputSettings: writerOutputSettings,
				   readerOutputSettings: readerOutputSettings)
		
		writer.transform = track.preferredTransform
	}
}

class MetadataCopier {
	
	let writer: AVAssetWriterInputMetadataAdaptor
	let metadata: AVMetadataItem
	
	private let duration: CMTime
	private let estimatedFrameCount: Int
	
	init(sharedAssetIdentifier: String, duration: CMTime, estimatedFrameCount: Int) {
		
		self.duration = duration
		self.estimatedFrameCount = estimatedFrameCount
		
		// Create neccesary identifier metadata and still image time metadata.
        let metadataItemForKeyPhoto = AVMutableMetadataItem()
        let keyContentIdentifier = "com.apple.quicktime.content.identifier"
        metadataItemForKeyPhoto.key = keyContentIdentifier as (NSCopying & NSObjectProtocol)?
        metadataItemForKeyPhoto.keySpace = AVMetadataKeySpace(rawValue: PHLivePhoto.keySpaceQuickTimeMetadata)
        metadataItemForKeyPhoto.value = sharedAssetIdentifier as (NSCopying & NSObjectProtocol)?
        metadataItemForKeyPhoto.dataType = "com.apple.metadata.datatype.UTF-8"
		metadata = metadataItemForKeyPhoto
		
		let spec : NSDictionary = [
			kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString: "\(PHLivePhoto.keySpaceQuickTimeMetadata)/\(PHLivePhoto.keyStillImageTime)",
			kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString: "com.apple.metadata.datatype.int8"
		]
		var desc : CMFormatDescription? = nil
		CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault,
																	metadataType: kCMMetadataFormatType_Boxed,
																	metadataSpecifications: [spec] as CFArray,
																	formatDescriptionOut: &desc)
		let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: desc)
		writer = AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
	}
	
	func copy() {
		
		// Make still image time range.
        var time = duration
        let frameDuration = Int64(Float(time.value) / Float(estimatedFrameCount))
        time.value = Int64(Float(time.value) * 0.5)
        let keyPhotoTimeLocation = CMTimeRangeMake(start: time, duration: CMTimeMake(value: frameDuration, timescale: time.timescale))
        
        // Add still image metadata.
        let metadataItemForStillImageTime = AVMutableMetadataItem()
        metadataItemForStillImageTime.key = "com.apple.quicktime.still-image-time" as (NSCopying & NSObjectProtocol)?
        metadataItemForStillImageTime.keySpace = AVMetadataKeySpace(rawValue: PHLivePhoto.keySpaceQuickTimeMetadata)
        metadataItemForStillImageTime.value = 0 as (NSCopying & NSObjectProtocol)?
        metadataItemForStillImageTime.dataType = "com.apple.metadata.datatype.int8"
		
		writer.append(AVTimedMetadataGroup(items: [metadataItemForStillImageTime], timeRange: keyPhotoTimeLocation))
	}
}

extension CGAffineTransform {
	
	enum HomeButtonLocation : String {
		case up
		case down
		case left
		case right
		case unknown
	}
	
	var homeButtonLocation: HomeButtonLocation {
		let transform = self
		let homeButtonUp = transform.a == 0.0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0.0
		let homeButtonLeft = transform.a == -1.0 && transform.b == 0.0 && transform.c == 0.0 && transform.d == -1.0
		let homeButtonRight = transform.a == 1.0 && transform.b == 0.0 && transform.c == 0.0 && transform.d == 1.0
		let homeButtonBottom = transform.a == 0.0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0.0
		if homeButtonUp {
			return .up
		} else if homeButtonLeft {
			return .left
		} else if homeButtonBottom {
			return .down
		} else if homeButtonRight {
			return .right
		} else {
			return .unknown
		}
	}
}

extension AVAssetTrack {
	
	func transformByMerging(into containerTrack: AVAssetTrack) -> CGAffineTransform {
		
		switch preferredTransform.homeButtonLocation {
			
		case .down:
			let ratio = containerTrack.naturalSize.height/naturalSize.width
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: .pi/2)
			let xTranslation = (containerTrack.naturalSize.width + naturalSize.height*ratio)/2
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: 0)
			return scale.concatenating(rotate).concatenating(translateBackToPoint)
			
		case .left:
			let ratio = containerTrack.naturalSize.width/naturalSize.width
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: .pi)
			let translateBackToPoint = CGAffineTransform(translationX: containerTrack.naturalSize.width,
														 y: containerTrack.naturalSize.height)
			return scale.concatenating(rotate).concatenating(translateBackToPoint)
			
		case .up:
			let ratio = containerTrack.naturalSize.height/naturalSize.width
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: -.pi/2)
			let xTranslation = (containerTrack.naturalSize.width - naturalSize.height*ratio)/2
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: containerTrack.naturalSize.height)
			return scale.concatenating(rotate).concatenating(translateBackToPoint)
			
		case .right, .unknown:
			let ratio = containerTrack.naturalSize.width/naturalSize.width
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			
			return CGAffineTransform.identity.concatenating(scale)
		}
	}
	
	func transformByMergingSideBySide(lhs: Bool, into containerTrack: AVAssetTrack) -> CGAffineTransform {
		
		// Container: 1440x1080
		// Source (original): 1308x980
		switch preferredTransform.homeButtonLocation {
			
		// Source (visual): 980x1308
		case .down:
			let ratio = containerTrack.naturalSize.width/(naturalSize.height * 2)
			
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: .pi/2)
			let emptySpace = containerTrack.naturalSize.width - naturalSize.height*ratio
			let xTranslation = lhs ? naturalSize.height*ratio : naturalSize.height*ratio + emptySpace
			let yTranslation = (containerTrack.naturalSize.height - naturalSize.width*ratio)/2
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: yTranslation)
			return scale.concatenating(rotate).concatenating(translateBackToPoint)
		
		// Source (visual): 1308x980
		case .left:
			// Origin before transforms: (-1308, 980)
			// x+ ->
			// y+ ^
			let ratio = containerTrack.naturalSize.width/naturalSize.width * 0.5
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: .pi)
			let emptySpace = containerTrack.naturalSize.height - naturalSize.height*ratio
			let halfEmptySpace = emptySpace/2
			let xTranslation = lhs ? naturalSize.width*ratio : naturalSize.width*ratio + (containerTrack.naturalSize.width/2)
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: halfEmptySpace + naturalSize.height*ratio)
			
			let transform = scale
				.concatenating(rotate)
				.concatenating(translateBackToPoint)
			
			return transform
			
		// Source (visual): 980x1308
		case .up:
			let ratio = containerTrack.naturalSize.width/(naturalSize.height * 2)
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let rotate = CGAffineTransform(rotationAngle: -.pi/2)
			let xTranslation = lhs ? 0 : containerTrack.naturalSize.width/2
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: (containerTrack.naturalSize.height + naturalSize.width*ratio)/2)
			return scale
				.concatenating(rotate)
				.concatenating(translateBackToPoint)
			
		// Source (visual): 1308x980
		case .right, .unknown:
			let ratio = containerTrack.naturalSize.width/naturalSize.width * 0.5
			let scale = CGAffineTransform(scaleX: ratio, y: ratio)
			let xTranslation = lhs ? 0 : containerTrack.naturalSize.width/2
			let translateBackToPoint = CGAffineTransform(translationX: xTranslation,
														 y: containerTrack.naturalSize.height * 0.25)
			
			return CGAffineTransform.identity.concatenating(scale).concatenating(translateBackToPoint)
		}
	}
}
