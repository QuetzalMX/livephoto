//
//  AmazingDecoder.swift
//  AmazingLivePhoto
//
//  Created by Fernando Olivares on 26/05/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import Foundation
import Photos
import AVKit
import MobileCoreServices

typealias SharedIdentifier = String

class AmazingDecoder {
	
	private let keyPhotoAsset: PHAssetResource
	private let keyVideoAsset: PHAssetResource
	
	private let urlHelper: SharedIdentifierURLCreator
	
	/// Initialization will fail if any of the following conditions are not met:
	/// - there is at least one asset of type `.photo`
	/// - there is at least one asset of type `.pairedVideo`.
	/// - `directoryURL` contains `isDirectoryKey: true`
	///
	/// Using either of the convenience initializers over this init is recommended.
	///
	/// - Parameters:
	///   - assets: only the first `.photo` and the first `pairedVideo` will be considered
	///   - directoryURL: must be
	init?(assets: [PHAssetResource], directoryURL: URL) {
		
		guard
			let keyPhotoResource = assets.first(where: { $0.type == .photo }),
			let keyVideoResource = assets.first(where: { $0.type == .pairedVideo }),
			directoryURL.isDirectory
		else {
			return nil
		}
		
		keyPhotoAsset = keyPhotoResource
		keyVideoAsset = keyVideoResource
		urlHelper = SharedIdentifierURLCreator(destinationURL: directoryURL)
	}
}

/// It would appear that both of these initializers are the same, but they are not.
/// - `PHAssetResource.assetResources(for: asset)` is actually two different functions.
/// - `PHAsset` and `PHLivePhoto` don't have a common protocol or ancestor.
extension AmazingDecoder {
	
	convenience init?(asset: PHAsset, directoryURL: URL) {
		let underlyingAssets = PHAssetResource.assetResources(for: asset)
		self.init(assets: underlyingAssets, directoryURL: directoryURL)
	}
	
	convenience init?(livePhoto: PHLivePhoto, directoryURL: URL) {
		let underlyingAssets = PHAssetResource.assetResources(for: livePhoto)
		self.init(assets: underlyingAssets, directoryURL: directoryURL)
	}
}

// MARK: - Decoding
extension AmazingDecoder {
	
	/// During decoding, we will copy the internal asset into `directoryURL/{sharedIdentifier}.jpeg`. If the process fails after this copy was created, the function attempts to remove `destinationURL/{sharedIdentifier}.jpeg`.
	///
	/// Removal is not guaranteed; check the error returned.
	///
	/// - Parameters:
	///   - allowsNetworkAccess: whether the asset should be downloaded, if a local copy is not reachable
	///   - completion: a resulting image with a shared identifier in its metadata
	func decodeKeyPhoto(allowsNetworkAccess: Bool = false,
						completion: @escaping (Result<PHLivePhotoKeyPhoto, DecodeError>) -> Void) {
		
		decode(.photo(keyPhotoAsset), allowsNetworkAccess: allowsNetworkAccess) { result in
			switch result {
				
			case .success(let identifierURLTuple):
				let keyPhotoComponent = PHLivePhotoKeyPhoto(sharedIdentifier: identifierURLTuple.0,
															url: identifierURLTuple.1)
				completion(.success(keyPhotoComponent))
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	/// During decoding, we will copy the internal asset into `directoryURL/{sharedIdentifier}.mov`. If the process fails after this copy was created, the function attempts to remove `destinationURL/{sharedIdentifier}.mov`.
	///
	/// Removal is not guaranteed; check the error returned.
	///
	/// - Parameters:
	///   - allowsNetworkAccess: whether the asset should be downloaded, if a local copy is not reachable
	///   - completion: a resulting image with a shared identifier in its metadata
	func decodeKeyVideo(allowsNetworkAccess: Bool = false,
						completion: @escaping (Result<PHLivePhotoKeyVideo, DecodeError>) -> Void) {
		
		decode(.video(keyVideoAsset), allowsNetworkAccess: allowsNetworkAccess) { result in
			switch result {
				
			case .success(let identifierURLTuple):
				let keyVideoComponent = PHLivePhotoKeyVideo(sharedIdentifier: identifierURLTuple.0,
															url: identifierURLTuple.1,
															audioURL: nil)
				completion(.success(keyVideoComponent))
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	private func decode(_ type: ComponentType,
						allowsNetworkAccess: Bool,
						completion: @escaping ((Result<(SharedIdentifier, URL), DecodeError>) -> Void)) {
		
		// We don't yet know what the item's `sharedIdentifier` is going to be; use a temporary filename.
		let tempFileURL = urlHelper.filepath(fileExtension: type.fileExtension)
		
		let options = PHAssetResourceRequestOptions()
		options.isNetworkAccessAllowed = allowsNetworkAccess
		
		// Fetch from library.
		let manager = PHAssetResourceManager.default()
		manager.writeData(for: type.resource, toFile: tempFileURL, options: options) { requestError in
			
			guard requestError == nil else {
				completion(.failure(.assetResourceManager(requestError!)))
				return
			}
			
			type.identifier(url: tempFileURL) { possibleIdentifier in
				
				// Since this should be a paired component that came from the library, it _must_ contain an identifier.
				guard let identifier = possibleIdentifier else {
					let cleanupError = FileManager.default.removeFile(at: tempFileURL)
					completion(.failure(.missingSharedIdentifier(cleanupError: cleanupError)))
					return
				}
				
				// Save the photo using the identifier as filename.
				let fileURL = self.urlHelper.filepath(identifier: identifier,
													  fileExtension: type.fileExtension)
				
				do {
					try FileManager.default.copyItem(at: tempFileURL, to: fileURL)
				} catch {
					let cleanupError = FileManager.default.removeFile(at: tempFileURL)
					completion(.failure(.writingToDisk(error, cleanupError: cleanupError)))
					return
				}
			}
		}
	}
}

extension AmazingDecoder {
	
	/// Exhaustive list of things that could go wrong when decoding a paired asset.
	enum DecodeError : Error {
		/// `PHAssetResourceManager` failed writing the asset from the photo library to the designated URL.
		case assetResourceManager(Error)
		
		/// `AmazingDecoder` only accepts paired assets from the photo library, so they _must_ contain an identifier already. If the copied asset could be removed, `cleanupError == nil`.
		case missingSharedIdentifier(cleanupError: Error?)
		
		/// Copying the file using the identifier as filename failed. If the copied asset could be removed, `cleanupError == nil`.
		case writingToDisk(Error, cleanupError: Error?)
	}
}

// MARK: - Helpers
extension AmazingDecoder {
	
	private enum ComponentType {
		
		case video(PHAssetResource)
		case photo(PHAssetResource)
		
		var fileExtension: SharedIdentifierURLCreator.URLType {
			switch self {
			case .photo: return .photo
			case .video: return .video
			}
		}
		
		var resource: PHAssetResource {
			switch self {
			case .photo(let resource), .video(let resource):
				return resource
			}
		}
		
		func identifier(url: URL, completion: @escaping (SharedIdentifier?) -> Void) {
			switch self {
				
			case .photo:
				
				guard
					let imageSource = CGImageSourceCreateWithURL(url as CFURL, [:] as CFDictionary),
					let imageCFProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, [:] as CFDictionary),
					let appleProperties = (imageCFProperties as NSDictionary)["{MakerApple}"] as? NSDictionary,
					let sharedIdentifier = appleProperties[PHLivePhoto.sharedIdentifierKey] as? String
					else {
						completion(nil)
						return
				}
				
				completion(sharedIdentifier)
				
			case .video:
				
				let asset = AVAsset(url: url)
				let formatsKey = "availableMetadataFormats"
				asset.loadValuesAsynchronously(forKeys: [formatsKey]) {
					
					let possibleIdentifierMetadataMatches = asset.availableMetadataFormats
						.flatMap { asset.metadata(forFormat: $0) }
						.filter { $0.commonKey?.rawValue == "identifier" }

					guard
						let identifierMetadataItem = possibleIdentifierMetadataMatches.first,
						let identifier = identifierMetadataItem.value as? String
					else {
						completion(nil)
						return
					}
					
					completion(identifier)
				}
			}
		}
	}
}
