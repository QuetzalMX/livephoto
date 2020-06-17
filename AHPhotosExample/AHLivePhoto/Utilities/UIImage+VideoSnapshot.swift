//
//  UIImage+VideoSnapshot.swift
//  Amazing Humans
//
//  Created by Fernando Olivares on 11/14/19.
//  Copyright © 2019 Fernando Olivares. All rights reserved.

import UIKit
import Photos
import MobileCoreServices

extension UIImage {
    
    enum KeyPhotoURLError : Error {
        case avAssetReader(Error)
		case assetAtURLHasNoMetadataTrack
        case keyPhotoTimeLocationNotFound
        case imageTimeLocationNotFound
        case cgImageGeneration(Error)
        case jpegConversion
        case writeToTempDirectory(Error)
    }
    
    private func image(fromVideoURL videoURL: URL, destination: URL) -> Result<URL, KeyPhotoURLError> {
        
        // Create our Asset Reader to get a key photo from the video.
        let videoAsset = AVURLAsset(url: videoURL)
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: videoAsset)
        } catch {
            return .failure(.avAssetReader(error))
        }
        
		// Get the metadata from the asset.
		guard let metadataTrack = videoAsset.tracks(withMediaType: .metadata).first else {
			return .failure(.assetAtURLHasNoMetadataTrack)
		}
		
		// We'll go through the video trying to find an image.
		let videoReaderOutput = AVAssetReaderTrackOutput(track: metadataTrack, outputSettings: nil)
		assetReader.add(videoReaderOutput)
		
		var possibleKeyPhotoTimeLocation: CMTime? = nil
		
		assetReader.startReading()
		repeat {
			
			guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else { break }
			
			guard
				CMSampleBufferGetNumSamples(sampleBuffer) != 0,
				let group = AVTimedMetadataGroup(sampleBuffer: sampleBuffer),
				let _ = group.items.first(where: { item in
					guard let itemKeyString = item.key as? String, let itemKeySpaceString = item.keySpace?.rawValue else { return false }
					
					return itemKeyString == PHLivePhoto.keyStillImageTime &&
						itemKeySpaceString == PHLivePhoto.keySpaceQuickTimeMetadata
				}) else { continue }
			
			possibleKeyPhotoTimeLocation = group.timeRange.start
			
		} while possibleKeyPhotoTimeLocation == nil
		assetReader.cancelReading()
		
		switch assetReader.status {
			
		case .cancelled:
			break
			
		case .completed:
			break
			
		case .failed:
			break
			
		case .reading:
			break
			
		case .unknown:
			break
			
		@unknown default:
			break
		}
		
		guard let time = possibleKeyPhotoTimeLocation else {
			return .failure(.keyPhotoTimeLocationNotFound)
		}
    
        // Generate an image using that time location.
        let percent = Float(time.value) / Float(videoAsset.duration.value)
        let generatedImage: UIImage
		
        let imageAssetGenerator = AVAssetImageGenerator(asset: videoAsset)
		imageAssetGenerator.appliesPreferredTrackTransform = true
		imageAssetGenerator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 100)
		imageAssetGenerator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 100)
        
		var frameTimeLocation = imageAssetGenerator.asset.duration
        frameTimeLocation.value = Int64(Float(time.value) * percent)
        
        do {
            var actualTime = CMTime.zero
			let imageRef = try imageAssetGenerator.copyCGImage(at: frameTimeLocation, actualTime:&actualTime)
            generatedImage = UIImage(cgImage: imageRef)
        }
        catch {
            return .failure(.cgImageGeneration(error))
        }
        
        // Convert the image to JPEG.
        guard let jpegData = generatedImage.jpegData(compressionQuality: 1.0) else {
            return .failure(.jpegConversion)
        }
        
        // Save the JPEG to disk.
        let imageURL = destination.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        do {
            try jpegData.write(to: imageURL)
            return .success(imageURL)
        } catch {
            return .failure(.writeToTempDirectory(error))
        }
    }
}
