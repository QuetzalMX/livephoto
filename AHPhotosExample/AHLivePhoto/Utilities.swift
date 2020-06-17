//
//  Utilities.swift
//  AHPhotosExample
//
//  Created by Fernando Olivares on 06/06/20.
//  Copyright © 2020 Fernando Olivares. All rights reserved.
//

import Foundation
import MobileCoreServices

class SharedIdentifierURLCreator {
	
	let destinationURL: URL
	let sharedIdentifier: String
	init(destinationURL: URL, sharedIdentifier: String? = nil) {
		self.destinationURL = destinationURL
		self.sharedIdentifier = sharedIdentifier ?? UUID().uuidString
	}
	
	func filepath(identifier: String? = nil, fileExtension: URLType) -> URL {
		return destinationURL
			.appendingPathComponent(identifier ?? sharedIdentifier)
			.appendingPathExtension(fileExtension.stringValue)
	}
	
	enum URLType {
		case photo
		case video
		case audio
		
		var stringValue: String {
			switch self {
			case .photo: return kUTTypeJPEG as String
			case .video: return "mov"// kUTTypeQuickTimeMovie as String (AVKit will not accept this)
			case .audio: return kUTTypeAudioInterchangeFileFormat as String
			}
		}
	}
}

extension URL {
    var isDirectory: Bool {
        let values = try? resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory ?? false
    }
}

extension FileManager {
	func removeFile(at URL: URL) -> Error? {
		do {
			try removeItem(at: URL)
			return nil
		} catch {
			return error
		}
	}
}
