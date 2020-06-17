////
////  PHLivePhotoURLComponents+Library.swift
////  AHPhotosExample
////
////  Created by Fernando Olivares on 26/05/20.
////  Copyright © 2020 Fernando Olivares. All rights reserved.
////
//
//import Foundation
//import Photos
//
//extension PHPhotoLibrary {
//	
//	func save(keyPhoto: PHLivePhotoKeyPhoto,
//			  keyVideo: PHLivePhotoKeyVideo,
//			  completion: @escaping (Error?) -> Void) {
//	
//		performChanges({
//			let creationRequest = PHAssetCreationRequest.forAsset()
//			let options = PHAssetResourceCreationOptions()
//			creationRequest.addResource(with: .pairedVideo, fileURL: keyVideo.url, options: options)
//			creationRequest.addResource(with: .photo, fileURL: keyPhoto.url, options: options)
//		}, completionHandler: { (success, error) in
//			
//			guard error == nil else {
//				completion(error!)
//				return
//			}
//			
//			guard success else {
//				completion(NSError(domain: "PHLivePhoto", code: 500, userInfo: nil))
//				return
//			}
//			
//			completion(nil)
//		})
//	}
//}
//
//extension PHLivePhoto {
//	
//	@discardableResult
//	static func generate(keyPhoto: PHLivePhotoKeyPhoto,
//						 keyVideo: PHLivePhotoKeyVideo,
//						 completion: @escaping (PHLivePhoto?) -> Void) -> PHLivePhotoRequestID {
//		
//		let keyURLs: [URL] = [
//			keyPhoto.url,
//			keyVideo.url,
//		]
//		
//		let requestID = request(withResourceFileURLs: keyURLs,
//								placeholderImage: nil,
//targetSize: CGSize.zero,
//contentMode: PHImageContentMode.aspectFit) { (possibleLivePhoto: PHLivePhoto?, info: [AnyHashable : Any]) -> Void in
//			
//			guard let livePhoto = possibleLivePhoto else {
//				completion(nil)
//				return
//			}
//			
//			if let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
//				return
//			}
//			
//			completion(livePhoto)
//		}
//		
//		return requestID
//	}
//	
//}
