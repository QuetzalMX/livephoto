//
//  PairedKeyPhotoCreator.swift
//  Amazing Humans
//
//  Created by Fernando Olivares on 02/05/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices
import Photos

class PairedKeyPhotoCreator {

	let inputURL: URL
	let outputURL: URL
	let identifier: String
	init(inputURL: URL, outputURL: URL, identifier: String) {
		self.inputURL = inputURL
		self.outputURL = outputURL
		self.identifier = identifier
	}
	
	enum RewriteError : Error {
		case fetchingKeyPhotoMetadata
		case writingKeyPhotoMetadata
	}
	
	func rewriteKeyPhoto() -> RewriteError? {
		
		// Copy the key photo metadata.
		guard
			let imageDestination = CGImageDestinationCreateWithURL(inputURL as CFURL, kUTTypeJPEG, 1, nil),
			let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
			var imageMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable : Any]
			else {
				return .fetchingKeyPhotoMetadata
		}
		
		// Save the key photo metadata with the shared identifier.
		imageMetadata[kCGImagePropertyMakerAppleDictionary] = [PHLivePhoto.sharedIdentifierKey : identifier]
		CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, imageMetadata as CFDictionary)
		guard CGImageDestinationFinalize(imageDestination) else {
			return .writingKeyPhotoMetadata
		}
		
		return nil
	}
}
