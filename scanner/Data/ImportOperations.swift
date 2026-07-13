//
//  ImportOperations.swift
//  Pagewise
//

import Foundation
import CoreData
import UIKit
import PDFKit
import os

/// Builds a new `Scan` from images or a PDF that didn't come from the camera
/// (Photos library or Files import), running the same OCR pipeline used for
/// camera-captured pages.
enum ImportOperations {

	/// - Returns: `true` if a scan was actually created (`images` was non-empty).
	@discardableResult
	static func createScan(fromImages images: [UIImage], in context: NSManagedObjectContext) -> Bool {
		guard !images.isEmpty else { return false }

		let scan = Scan(context: context)
		scan.createDefaults()

		for (index, image) in images.enumerated() {
			let capture = ScanCapture(context: context)
			capture.id = UUID()
			capture.timestamp = Date()
			capture.order = Int32(index)
			capture.createImage(fullSizedImage: image)
			capture.createThumbnail(fullSizedImage: image)

			let captureOcr = CaptureOcr(scan: scan, capture: capture, image: image, setScanTitle: index == 0)
			captureOcr.performOcr()

			scan.addToCaptures(capture)
		}

		saveContext(context)
		return true
	}

	/// Renders each page of the PDF at `url` to an image and imports it the same
	/// way as a set of photos. `url` must already be accessible (security-scoped
	/// access started by the caller when the URL comes from a file picker).
	///
	/// - Returns: `true` if a scan was actually created — `false` if the PDF
	///   couldn't be opened or none of its pages could be rendered, so callers
	///   can avoid signaling success (e.g. a success haptic) for a no-op import.
	@discardableResult
	static func createScan(fromPDF url: URL, in context: NSManagedObjectContext) -> Bool {
		guard let document = PDFDocument(url: url) else { return false }

		var images: [UIImage] = []
		for pageIndex in 0..<document.pageCount {
			guard let page = document.page(at: pageIndex) else { continue }
			if let image = renderImage(for: page) {
				images.append(image)
			}
		}

		return createScan(fromImages: images, in: context)
	}

	private static func renderImage(for page: PDFPage) -> UIImage? {
		let pageRect = page.bounds(for: .mediaBox)
		guard pageRect.width > 0, pageRect.height > 0 else { return nil }

		let renderer = UIGraphicsImageRenderer(size: pageRect.size)
		return renderer.image { context in
			UIColor.white.set()
			context.fill(pageRect)

			context.cgContext.translateBy(x: 0, y: pageRect.size.height)
			context.cgContext.scaleBy(x: 1, y: -1)
			page.draw(with: .mediaBox, to: context.cgContext)
		}
	}

	private static func saveContext(_ context: NSManagedObjectContext) {
		if context.hasChanges {
			do {
				try context.save()
			} catch {
				let nsError = error as NSError
				Logger.app.error("Error saving imported scan: \(nsError, privacy: .public)")
			}
		}
	}
}
