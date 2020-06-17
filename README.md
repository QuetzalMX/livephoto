# AmazingLivePhoto

AmazingLivePhoto helps you encode/decode PHLivePhotos into their components: an image and a video. 

Its goal is to make it easy to:
- Create a PHLivePhoto out of an image and a video
- Fetch the image and video of a PHLivePhoto or PHAsset with subtype livePhoto.

## Quick Start

Encoding:

```
// Get URLs to an image and a video saved to disk.
let encoder = AmazingEncoder(keyPhotoURL: savedImageURL, videoURL: savedVideoURL, destinationURL: FileManager.default.cacheDirectory)!
		
    // Generating a paired key photo copies the photo @ savedImageURL and appends metadata to specify that it is half of a PHLivePhoto.
		switch encoder.generatePairedKeyPhoto() {
			
		case .success(let encodedLivePhoto):
			self.encodedKeyPhoto = encodedLivePhoto
			
		case .failure(let error):
			print(error)
		}
		
    // Generating a paired key photo copies the video @ savedVideoURL and appends metadata to specify that it is half of a PHLivePhoto.
		encoder.generatePairedVideo { result in
			switch result {
			case .success(let encodedLiveVideo):
				self.encodedKeyVideo = encodedLiveVideo
				
			case .failure(let error):
				print(error)
			}
		}

```
