//
//  AmazingDecoder.swift
//  AmazingLivePhoto
//
//  Created by Fernando Olivares on 26/05/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.

import Foundation
import Photos

struct PHLivePhotoKeyPhoto : Codable, Equatable {
	
	/// The image located at `url` will have this identifier in its metadata.
	let sharedIdentifier: String
	
	/// Filename is `sharedIdentifier.jpeg`
	let url: URL
}

struct PHLivePhotoKeyVideo : Codable, Equatable {
	/// The video located at `url` will have this identifier in its metadata.
	let sharedIdentifier: String
	
	/// Contains a video and, if possible, audio.
	/// Filename is `sharedIdentifier.mov`
	let url: URL
	
	/// Audio-only (if it exists).
	/// Filename is `sharedIdentifier.aiff`.
	let audioURL: URL?
}

extension PHLivePhoto {
	// "17" is the asset identifier for live photos.
	static let sharedIdentifierKey = "17"
	static let keyStillImageTime = "com.apple.quicktime.still-image-time"
	static let keySpaceQuickTimeMetadata = "mdta"
}
