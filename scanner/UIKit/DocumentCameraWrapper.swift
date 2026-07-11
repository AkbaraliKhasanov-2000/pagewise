//
//  DocumentCameraWrapper.swift
//  DocSnap
//

import Foundation
import SwiftUI
import Vision
import VisionKit
import os

final class CameraScanViewModel: NSObject, ObservableObject {
	@Published var errorMessage: String?
	@Published var imageArray: [UIImage] = []
	@Published var scan: Scan?
	
	func getDocumentCameraViewController() -> VNDocumentCameraViewController {
		let vc = VNDocumentCameraViewController()
		vc.delegate = self
		return vc
	}
	
	func removeImage(image: UIImage) {
		imageArray.removeAll{$0 == image}
	}
}


extension CameraScanViewModel: VNDocumentCameraViewControllerDelegate {
	
	func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
		// `PageScan` (the SwiftUI screen behind this modal) never remounts on
		// its own once the camera is dismissed, so without this the screen is
		// left blank — closing the camera looked broken because nothing
		// visibly happened. Explicitly navigate back to the document list.
		controller.dismiss(animated: true) {
			AppState.shared.viewState = .Home
		}
	}
	
	func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
		errorMessage = error.localizedDescription
		Logger.app.error("Document camera failed: \(error, privacy: .public)")
		// Same fix as the cancel/finish paths — otherwise a camera failure
		// leaves the blank `PageScan` screen behind with no way out.
		controller.dismiss(animated: true) {
			AppState.shared.viewState = .Home
		}
	}
	
	func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
		let viewContext = PersistenceController.shared.container.viewContext
		let newScan = Scan(context: viewContext)
		newScan.createDefaults()
		self.scan = newScan
		for i in 0..<scan.pageCount {
			let capture = ScanCapture(context: viewContext)
			capture.id = UUID()
			capture.timestamp = Date()
			capture.order = Int32(i)
			let image = scan.imageOfPage(at:i)
			capture.createImage(fullSizedImage: image)
			capture.createThumbnail(fullSizedImage: image)
			let captureOcr = CaptureOcr(scan: newScan, capture: capture, image: image, setScanTitle: i == 0)
			captureOcr.performOcr()
			newScan.addToCaptures(capture)
		}
		let didSave = saveContext()
		if didSave {
			Haptics.success()
			AppState.shared.requestReviewIfNecessary()
		} else {
			// The scan couldn't be persisted — tell the user with distinct
			// feedback rather than the same haptic as a successful save.
			Haptics.error()
		}
		// Same fix as the cancel path: navigate back explicitly rather than
		// leaving the blank `PageScan` screen behind once this dismisses.
		// On success, open the scan that was just captured so the user lands
		// somewhere useful instead of the (now Home) list.
		controller.dismiss(animated: true) {
			if didSave {
				AppState.shared.openScan = newScan
			}
			AppState.shared.viewState = .Home
		}
	}

	@discardableResult
	func saveContext() -> Bool {
		let viewContext = PersistenceController.shared.container.viewContext
		guard viewContext.hasChanges else { return true }
		do {
			try viewContext.save()
			return true
		} catch {
			let nserror = error as NSError
			Logger.app.error("Error saving context: \(nserror, privacy: .public)")
			return false
		}
	}

}

struct CaptureOcr {
	
	var scan: Scan
	var capture: ScanCapture
	var image: UIImage
	@State var setScanTitle: Bool = false
	
	func performOcr() {
		
		// Get the CGImage on which to perform requests.
		guard let cgImage = image.cgImage else { return }
		
		// Create a new image-request handler.
		let requestHandler = VNImageRequestHandler(cgImage: cgImage)
		
		// Create a new request to recognize text.
		let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
		
		request.recognitionLevel = .accurate
		
		request.automaticallyDetectsLanguage = true
		request.revision = VNRecognizeTextRequestRevision3
		
		request.usesLanguageCorrection = true

		do {
			// Perform the text-recognition request.
			try requestHandler.perform([request])
		} catch {
			Logger.app.error("OCR request failed: \(error, privacy: .public)")
		}
		
	}
	
	func recognizeTextHandler(request: VNRequest, error: Error?) {
		guard let observations =
				request.results as? [VNRecognizedTextObservation] else {
			return
		}
		let recognizedStrings = observations.compactMap { observation in
			// Return the string of the top VNRecognizedText instance.
			return observation.topCandidates(1).first?.string
		}
		
		// Process the recognized strings.
		processOcrResults(recognizedStrings)
		saveContext()
	}
	
	func processOcrResults(_ found: [String]) {
		guard let context = capture.managedObjectContext else { return }
		for text in found {
			let item = ScanRecognizedItem(context: context)
			item.id = UUID()
			item.order = Int32(capture.recognizedItemsArray.count)
			item.timestamp = Date()
			item.transcript = text
			capture.addToRecognizedItems(item)
		}
	}

	func saveContext() {
		if setScanTitle {
			if let title = capture.recognizedItemsArray.first?.transcript?.whitespaceCondensed().truncate(to: 50) {
				scan.title = title
			}
		}

		guard let viewContext = capture.managedObjectContext else { return }
		if viewContext.hasChanges {
			do {
				try viewContext.save()
			} catch {
				let nserror = error as NSError
				Logger.app.error("Error saving context: \(nserror, privacy: .public)")
			}
		}
	}

}
