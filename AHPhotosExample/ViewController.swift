//
//  ViewController.swift
//  AHPhotosExample
//
//  Created by Fernando Olivares on 10/04/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import UIKit
import Photos
import AVKit

class ViewController: UIViewController {
	
	var fetchedLivePhoto: PHLivePhoto?
	
	var decodedKeyPhoto: PHLivePhotoKeyPhoto!
	var decodedKeyVideo: PHLivePhotoKeyVideo!
	
	var encodedKeyPhoto: PHLivePhotoKeyPhoto!
	var encodedKeyVideo: PHLivePhotoKeyVideo!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		fetchSingleLivePhoto { fetchedLivePhoto in
			
			let decoder = AmazingDecoder(livePhoto: fetchedLivePhoto,
										 directoryURL: FileManager.default.cacheDirectory)!
			
			decoder.decodeKeyPhoto() { result in
				switch result {
				case .success(let keyPhotoComponent):
					self.decodedKeyPhoto = keyPhotoComponent

				case .failure(let error):
					print(error)
				}
			}
			
			decoder.decodeKeyVideo() { result in
				switch result {
				case .success(let keyVideoComponent):
					self.decodedKeyVideo = keyVideoComponent

				case .failure(let error):
					print(error)
				}
			}
		}
	}
	
	@IBAction func encode() {
		let encoder = AmazingEncoder(keyPhotoURL: decodedKeyPhoto.url,
									 videoURL: decodedKeyVideo.url,
									 destinationURL: FileManager.default.cacheDirectory)!
		
		switch encoder.generatePairedKeyPhoto() {
			
		case .success(let encodedLivePhoto):
			self.encodedKeyPhoto = encodedLivePhoto
			
		case .failure(let error):
			print(error)
		}
		
		encoder.generatePairedVideo { result in
			switch result {
			case .success(let encodedLiveVideo):
				self.encodedKeyVideo = encodedLiveVideo
				
			case .failure(let error):
				print(error)
			}
		}
	}
	
	@IBAction func showEncoded() {
		
	}
}

extension ViewController : AVPlayerViewControllerDelegate {
	func fetchSingleLivePhoto(completion: @escaping (PHLivePhoto) -> Void) {
		
		PHPhotoLibrary.requestAuthorization { (status) in
					switch status {
						
					case .authorized:
						let options = PHFetchOptions()
						options.fetchLimit = 1
						PHAsset.fetchLivePhotoAssets(options: options).enumerateObjects { (asset, assetIndex, stop) in
							
							PHImageManager.default().requestLivePhoto(for: asset, targetSize: .zero, contentMode: .default, options: nil) { (possibleLivePhoto, info) in
								
								guard let livePhoto = possibleLivePhoto else {
									return
								}
								
								if let isDegraded = info?[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
									return
								}
								
								guard self.fetchedLivePhoto == nil else { return }
								
								self.fetchedLivePhoto = livePhoto
								completion(livePhoto)
							}
						}
						
					case .denied, .restricted:
						print("Not allowed")
						
					case .notDetermined:
						print("Not determined yet")
						
					@unknown default:
						fatalError("Unsupported status when requesting authorization")
					}
				}
	}
}

extension PHAsset {
	
	class func fetchLivePhotoAssets(options: PHFetchOptions) -> PHFetchResult<PHAsset> {
		
		let livePhotoPredicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
		if let existingPredicate = options.predicate {
			options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [existingPredicate, livePhotoPredicate])
		} else {
			options.predicate = livePhotoPredicate
		}

		return PHAsset.fetchAssets(with: options)
	}
}

extension FileManager {
	
	var cacheDirectory: URL {
		let cacheDirectoryURL = try! url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		let fullDirectory = cacheDirectoryURL.appendingPathComponent("PHLivePhotoComponents", isDirectory: true)
		if !fileExists(atPath: fullDirectory.absoluteString) {
			try! createDirectory(at: fullDirectory, withIntermediateDirectories: true, attributes: nil)
		}
		
		return fullDirectory
	}
}
