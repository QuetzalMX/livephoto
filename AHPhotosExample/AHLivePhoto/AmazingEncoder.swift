//
//  AmazingEncoder.swift
//  Amazing Humans
//
//  Created by Fernando Olivares on 11/17/19.
//  Copyright © 2019 Fernando Olivares. All rights reserved.
//

import UIKit
import Photos

class AmazingEncoder {
	
	private let keyPhotoURL: URL
	private let videoURL: URL
	
	private let urlHelper: SharedIdentifierURLCreator
	
	/// Will return nil if `destinationURL` is not a directory.
	///
	/// - Parameters:
	///   - photoURL: an image on disk
	///   - videoURL: a video on disk
	///   - sharedIdentifier: can be any string, use the default value when possible
	///   - destinationURL: both photo and video will be saved to this directory
	init?(keyPhotoURL: URL, videoURL: URL, sharedIdentifier: String = UUID().uuidString, destinationURL: URL) {
		
		guard destinationURL.isDirectory else {
			return nil
		}
		
		self.keyPhotoURL = keyPhotoURL
		self.videoURL = videoURL
		urlHelper = SharedIdentifierURLCreator(destinationURL: destinationURL,
											   sharedIdentifier: sharedIdentifier)
	}
}

extension AmazingEncoder {
	
	/// Generating a paired photo is a three-step process:
	/// - Copy the image at `keyPhotoURL` to `destinationURL/{sharedIdentifier}.jpeg`.
	/// - Read the image metadata from `destinationURL/{sharedIdentifier}.jpeg`.
	/// - Add `{sharedIdentifier}` key to the image metadata.
	///
	/// If reading image metadata or writing image metadata fail, the function attempts to remove `destinationURL/{sharedIdentifier}.jpeg`. Removal is not guaranteed; check the error returned.
	///
	/// - Returns: a copy of the contents at `keyPhotoURL` with `sharedIdentifier` in its metadata
	func generatePairedKeyPhoto() -> Result<PHLivePhotoKeyPhoto, GeneratePairedKeyPhotoError>  {
		
		let pairedKeyPhotoURL = urlHelper.filepath(fileExtension: .photo)
		
		// Copy the photo.
		do {
			try FileManager.default.copyItem(at: keyPhotoURL, to: pairedKeyPhotoURL)
		} catch {
			return .failure(.copy(error))
		}
		
		// Copy the metadata.
		let photoExtension = SharedIdentifierURLCreator.URLType.photo.stringValue
		guard
			let imageDestination = CGImageDestinationCreateWithURL(pairedKeyPhotoURL as CFURL, photoExtension as CFString, 1, nil),
			let imageSource = CGImageSourceCreateWithURL(pairedKeyPhotoURL as CFURL, nil),
			var imageMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable : Any]
			else {
				let cleanupError = FileManager.default.removeFile(at: pairedKeyPhotoURL)
				return .failure(.fetchingKeyPhotoMetadata(cleanupError: cleanupError))
		}
		
		// Save the key photo metadata with the shared identifier.
		imageMetadata[kCGImagePropertyMakerAppleDictionary] = [PHLivePhoto.sharedIdentifierKey : urlHelper.sharedIdentifier]
		CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, imageMetadata as CFDictionary)
		guard CGImageDestinationFinalize(imageDestination) else {
			let cleanupError = FileManager.default.removeFile(at: pairedKeyPhotoURL)
			return .failure(.writingKeyPhotoMetadata(cleanupError: cleanupError))
		}
		
		let pairedPhoto = PHLivePhotoKeyPhoto(sharedIdentifier: urlHelper.sharedIdentifier,
											  url: pairedKeyPhotoURL)
		return .success(pairedPhoto)
	}
	
	/// Generating a paired video is a two-step process:
	/// - AVKit validates the video input
	/// - AVKit copies the video and appends `shareIdentifier` to the copied video's metadata.
	///
	/// The resulting paired video will also have accompanying audio, if possible.
	///
	/// Since the copy happens via AVKit, cleanup is not our responsibility.
	///
	/// - Parameter completion: receives a copy of the contents at `keyVideoURL` with `sharedIdentifier` in its metadata
	func generatePairedVideo(completion: @escaping (Result<PHLivePhotoKeyVideo, GeneratePairedVideoError>) -> Void) {
		
		let pairedVideoURL = urlHelper.filepath(fileExtension: .video)
		let pairedAudioURL = urlHelper.filepath(fileExtension: .audio)
		
		// Send the asset to AVKit to see if it can work with it.
		let pairedVideoCopier: AmazingVideoCopier
		do {
			pairedVideoCopier = try AmazingVideoCopier(inputURL: videoURL,
													   videoOutputURL: pairedVideoURL,
													   audioOutputURL: pairedAudioURL,
													   identifier: urlHelper.sharedIdentifier)
		} catch {
			completion(.failure(.assetWriter(error)))
			return
		}
		
		pairedVideoCopier.rewriteVideo { possibleError in
			
			guard possibleError == nil else {
				completion(.failure(.copy(possibleError!)))
				return
			}
			
			let pairedVideo = PHLivePhotoKeyVideo(sharedIdentifier: self.urlHelper.sharedIdentifier,
												  url: pairedVideoURL,
												  audioURL: nil)
			completion(.success(pairedVideo))
		}
	}
	
	/// Exhaustive list of things that could go wrong when generating a paired key photo.
	enum GeneratePairedKeyPhotoError : Error {
		/// Copying the original asset failed.
		case copy(Error)
		
		/// After the copy has been made, the metadata could not be read. If the copied asset could be removed, `cleanupError == nil`.
		case fetchingKeyPhotoMetadata(cleanupError: Error?)
		
		/// After reading the metadata, writing `{sharedIdentifier}` failed. If the copied asset could be removed, `cleanupError == nil`.
		case writingKeyPhotoMetadata(cleanupError: Error?)
	}
	
	/// Exhaustive list of things that could go wrong when generating a paired video.
	enum GeneratePairedVideoError : Error {
		
		/// AVAssetReader or AVAssetWriter did not like something in the video URL. Check the associated error for more information.
		case assetWriter(Error)
		
		/// Copying the original asset failed. This could be a video or audio failure. Check the associated error for more information.
		case copy(Error)
	}
}
