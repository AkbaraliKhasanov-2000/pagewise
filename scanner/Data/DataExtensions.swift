//
//  DataExtensions.swift
//  Pagewise
//

import Foundation
import CoreData
import UIKit
import PDFKit
import Vision
import os

extension Scan {
	
	public func createDefaults(isLive: Bool = false) {
		// Init
		id = UUID()
		timestamp = Date()
		title = "Scan from " + timestamp!.formatted()
		order = Int32(AppState.shared.lastScanIndex)
		self.isLive = isLive
		if let location = AppState.shared.locationManager.myLocation {
			latitude = location.coordinate.latitude
			longitude = location.coordinate.longitude
		}
		
	}
	
	public var capturesArray: [ScanCapture] {
	  let set = captures as? Set<ScanCapture> ?? []
	  return set.sorted {
		$0.order < $1.order
	  }
	}

	/// Free-form tags, stored as a single comma-delimited string
	/// (`tagsRaw`, wrapped in leading/trailing commas — e.g. `",work,2026,"`)
	/// so a single `CONTAINS` predicate can match a whole tag without
	/// false-positiving on substrings (e.g. "art" inside "cart").
	public var tags: [String] {
		get {
			guard let raw = tagsRaw else { return [] }
			return raw.split(separator: ",").map(String.init)
		}
		set {
			let cleaned = newValue
				// Commas are the field delimiter in `tagsRaw` — strip them out of
				// each tag's text so a tag can never be silently split in two.
				.map { $0.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
			var seen = Set<String>()
			let deduped = cleaned.filter { seen.insert($0.lowercased()).inserted }
			tagsRaw = deduped.isEmpty ? nil : "," + deduped.joined(separator: ",") + ","
		}
	}

	public func addTag(_ tag: String) {
		let trimmed = tag.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
		tags.append(trimmed)
	}

	public func removeTag(_ tag: String) {
		tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
	}
	
	public var reversedCaptures: [ScanCapture] {
		(captures?.allObjects as? [ScanCapture] ?? [])
			.sorted(by: { $0.order > $1.order })
	}
	
	public var totalRecognizedItems: Int {
		var result = 0
		for capture in capturesArray {
			result += capture.recognizedItems?.count ?? 0
		}
		return result
	}
	
	public var firstThumbnail: UIImage? {
		
		for capture in capturesArray {
			if let data = capture.thumbnailData {
				if let image = UIImage(data: data) {
					return image
				}
			}
		}
		return nil
	}
	
	public var lastThumbnail: UIImage? {
		
		for capture in capturesArray.reversed() {
			if let data = capture.thumbnailData {
				if let image = UIImage(data: data) {
					return image
				}
			}
		}
		return nil
	}
	
	public var textPreview: String {
		var result = ""
		for capture in capturesArray {
			result = result.trimmingCharacters(in: .whitespaces) + " " + capture.textPreview
			if result.count > 200 {
				return result
			}
		}
		return result
	}
	
	
	public func pdfDocument(addWatermark: Bool = false) -> PDFDocument {
		let flatPdf = PDFDocument()

		// Add all pages to the document, each with an invisible OCR text layer
		// so the exported PDF is searchable and its text selectable, not just a picture.
		for capture in reversedCaptures {
			if let image = prepareImageForExport(capture.image) {
				if let newPage = Scan.searchablePDFPage(for: image) {
					flatPdf.insert(newPage, at: 0)
				}
			}
		}

		return flatPdf
	}

	/// Renders `image` as a full-page PDF page with an invisible text layer
	/// positioned over each line Vision recognizes, so the page's text is
	/// searchable and selectable in PDF viewers while looking identical to a
	/// plain scanned image.
	private static func searchablePDFPage(for image: UIImage) -> PDFPage? {
		let pageRect = CGRect(origin: .zero, size: image.size)
		let observations = recognizedTextObservations(in: image)

		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		let data = renderer.pdfData { context in
			context.beginPage()
			image.draw(in: pageRect)

			let cgContext = context.cgContext
			cgContext.saveGState()
			cgContext.setTextDrawingMode(.invisible)

			for observation in observations {
				guard let candidate = observation.topCandidates(1).first else { continue }
				let box = observation.boundingBox
				let rect = CGRect(
					x: box.minX * image.size.width,
					y: (1 - box.maxY) * image.size.height,
					width: box.width * image.size.width,
					height: box.height * image.size.height
				)
				guard rect.height > 0 else { continue }
				let font = UIFont.systemFont(ofSize: rect.height * 0.85)
				(candidate.string as NSString).draw(in: rect, withAttributes: [.font: font])
			}

			cgContext.restoreGState()
		}

		guard let pdfDoc = PDFDocument(data: data) else { return nil }
		return pdfDoc.page(at: 0)
	}

	private static func recognizedTextObservations(in image: UIImage) -> [VNRecognizedTextObservation] {
		guard let cgImage = image.cgImage else { return [] }

		let request = VNRecognizeTextRequest()
		request.recognitionLevel = .accurate
		request.usesLanguageCorrection = true
		request.automaticallyDetectsLanguage = true

		let handler = VNImageRequestHandler(cgImage: cgImage)
		do {
			try handler.perform([request])
			return request.results ?? []
		} catch {
			Logger.app.error("Searchable PDF OCR failed: \(error, privacy: .public)")
			return []
		}
	}
	
	private func prepareImageForExport(_ image: UIImage?, addWatermark: Bool = false) -> UIImage? {
		guard let image = image else { return nil }

		// Return the original image
		return image
	}
	
	private func renderWatermark(inImage image: UIImage, qrImage: UIImage? = nil) -> UIImage {

		guard let qrImage = qrImage else { return image }
		
		UIGraphicsBeginImageContextWithOptions(image.size, false, 1)

		image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
		
		let padding = image.size.width / 50
		let width = image.size.width / 8
		let height = width / (qrImage.size.width / qrImage.size.height)
		let rect = CGRect(x: image.size.width - width - padding, y: image.size.height - height - padding, width: width, height: height)
		
		qrImage.draw(in: rect)

		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		return newImage!
	}
	
	public func pdfDocumentFile(addWatermark: Bool = false) -> URL? {

		// Save file
		let filename = ((title ?? "Document") + ".pdf").sanitized().whitespaceCondensed()
		let url = FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent(filename)

		let didWrite = pdfDocument().write(to: url)
		
		return didWrite ? url : nil
	}
	
	func firstPageImage() -> UIImage? {
		guard let document = CGPDFDocument(pdfDocumentFile()! as CFURL) else { return nil }
		guard let page = document.page(at: 1) else { return nil }

		let pageRect = page.getBoxRect(.mediaBox)
		let renderer = UIGraphicsImageRenderer(size: pageRect.size)
		let img = renderer.image { ctx in
			UIColor.white.set()
			ctx.fill(pageRect)

			ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
			ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

			ctx.cgContext.drawPDFPage(page)
		}

		return img
	}
	
	public var textDocument: URL? {
		var str = ""
		
		// Add all pages to the document
		for capture in capturesArray {
			for item in capture.recognizedItemsArray {
				str += (item.transcript ?? "") + "\n"
			}
		}

		// Save file
		let filename = ((title ?? "Document") + ".text").sanitized().whitespaceCondensed()
		let url = FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent(filename)

		do {
			try str.write(to: url, atomically: true, encoding: String.Encoding.utf8)
			return url
		} catch {
			// Failed
		}
		
		return nil
	}
}

extension ScanCapture {
	
	public var recognizedItemsArray: [ScanRecognizedItem] {
	  let set = recognizedItems as? Set<ScanRecognizedItem> ?? []
	  return set.sorted {
		($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast)
	  }
	}
	
	public var image: UIImage? {
		if let data = imageData {
			if let image = UIImage(data: data) {
				return image
			}
		}
		return nil
	}
	
	public var thumbnail: UIImage? {
		if let data = thumbnailData {
			if let image = UIImage(data: data) {
				return image
			}
		}
		return nil
	}
	
	public func createImage(fullSizedImage: UIImage) {
		let newWidth = 2400.0
		imageData = fullSizedImage.resizeToWidth(newWidth).jpegData(compressionQuality: 0.75)
	}
	
	public func createThumbnail(fullSizedImage: UIImage? = nil) {
		let newWidth = 360.0
		if let fullSizedImage = fullSizedImage {
			thumbnailData = fullSizedImage.resizeToWidth(newWidth).jpegData(compressionQuality: 0.75)
		} else if let image = image {
			thumbnailData = image.resizeToWidth(newWidth).jpegData(compressionQuality: 0.75)
		}
	}

	public var currentFilter: ScanImageFilter {
		ScanImageFilter(rawValue: filterName ?? "") ?? .original
	}

	/// Applies `filter` to this page, replacing `imageData`/`thumbnailData`.
	/// The first time a filter is applied, the untouched capture is preserved
	/// in `originalImageData` so switching filters (or choosing `.original`
	/// again) always re-derives from the pristine image instead of compounding
	/// quality loss from a previously applied filter.
	public func applyFilter(_ filter: ScanImageFilter) {
		if originalImageData == nil {
			originalImageData = imageData
		}
		guard let baseData = originalImageData, let baseImage = UIImage(data: baseData) else { return }

		let filteredImage = filter.apply(to: baseImage)
		createImage(fullSizedImage: filteredImage)
		createThumbnail(fullSizedImage: filteredImage)
		filterName = filter.rawValue
	}

	/// Draws `signature` (a transparent-background ink image from
	/// `SignaturePadView`) onto the page as it currently looks (post-filter),
	/// then re-derives `imageData`/`thumbnailData`.
	///
	/// The signed result becomes the new baseline (see `commitAsOriginal()`):
	/// otherwise a later `applyFilter` call would regenerate the page from
	/// the pre-signature `originalImageData` and silently erase the signature.
	public func addSignature(_ signature: UIImage) {
		guard let currentImage = image else { return }
		let signed = currentImage.compositingSignature(signature)
		createImage(fullSizedImage: signed)
		createThumbnail(fullSizedImage: signed)
		commitAsOriginal()
	}

	/// Marks the page's current `imageData` as the new pristine baseline for
	/// future filtering, and clears `filterName` since no filter has been
	/// applied relative to this new baseline yet. Call this after any edit
	/// that writes `imageData` directly outside of `applyFilter` (adding a
	/// signature, QuickLook markup) — otherwise a later `applyFilter` call
	/// would regenerate the page from the stale pre-edit `originalImageData`
	/// and silently discard the edit.
	public func commitAsOriginal() {
		originalImageData = imageData
		filterName = nil
	}
	
	public var textPreview: String {
		var result = ""
		for item in recognizedItemsArray {
			if let text = item.transcript {
				result = result.trimmingCharacters(in: .whitespaces) + " " + text.replacingOccurrences(of: "\n", with: " ")
				if result.count > 200 {
					return result
				}
			}
		}
		return result
	}
	
	public var titleSuggestion: String {
		var title = parent?.title ?? "Scanned text"
		if let firstItem = recognizedItemsArray.first {
			title = firstItem.transcript?.sanitized().whitespaceCondensed() ?? title
		}
		return title
	}
	
	public var textDocument: URL? {
		var str = ""
		
		// Add all page text
		for item in recognizedItemsArray {
			if let text = item.transcript {
				str = str + text + "\n"
			}
		}

		// Save file
		let filename = (titleSuggestion + ".text").sanitized().whitespaceCondensed()
		let url = FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent(filename)

		do {
			try str.write(to: url, atomically: true, encoding: String.Encoding.utf8)
			return url
		} catch {
			// Failed
		}
		
		return nil
	}

}

extension ScanRecognizedItem {
	
	public var titleSuggestion: String {
		var title = parent?.titleSuggestion ?? "Scanned text"
		title = transcript?.sanitized().whitespaceCondensed() ?? title
		return title
	}
	
	public var textUrl: URL? {

		guard let str = transcript else { return nil }

		// Save file
		let filename = titleSuggestion + ".text"
		let url = FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent(filename)

		do {
			try str.write(to: url, atomically: true, encoding: String.Encoding.utf8)
			return url
		} catch {
			// Failed
		}
		
		return nil
	}
	
	var mailingAddress: String? {
		
		if let result = dataDetector(transcript, checkingType: .address) {
			return result
		}
		return nil
	}
	
	var phoneNumber: String? {
		
		if let result = dataDetector(transcript, checkingType: .phoneNumber) {
			return result
		}
		return nil
	}
	
	var urlAddress: String? {
		
		if let result = dataDetector(transcript, checkingType: .link) {
			return result
		}
		return nil
	}
	
	var emailAddress: String? {
		
		if let result = dataDetector(transcript, checkingType: .link, isEmail: true) {
			return result
		}
		return nil
	}
	

	func dataDetector(_ text: String?, checkingType: NSTextCheckingResult.CheckingType, isEmail: Bool = false) -> String? {

		guard let text = text else { return nil }
		
		do {
			// Create an NSDataDetector to parse the text, searching for various fields of interest.
			let detector = try NSDataDetector(types: NSTextCheckingAllTypes)
			let matches = detector.matches(in: text, options: .init(), range: NSRange(location: 0, length: text.count))
			for match in matches {
				let matchStartIdx = text.index(text.startIndex, offsetBy: match.range.location)
				let matchEndIdx = text.index(text.startIndex, offsetBy: match.range.location + match.range.length)
				let matchedString = String(text[matchStartIdx..<matchEndIdx])
				
				if match.resultType == checkingType {
					
					if isEmail && checkingType == .link {
						if matchedString.contains("@") {
							return matchedString
						}
					}
					else if !isEmail && checkingType == .link {
						if !matchedString.contains("@") {
							return matchedString
						}
					}
					else {
						return matchedString
					}
				}
				
			}
		} catch {
			Logger.app.error("Data detector failed: \(error, privacy: .public)")
		}
		return nil
	}
	
	
}

struct CreateOperation<Object: NSManagedObject>: Identifiable {
	let id = UUID()
	let childContext: NSManagedObjectContext
	let childObject: Object
	
	init(with parentContext: NSManagedObjectContext) {
		let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		childContext.parent = parentContext
		let childObject = Object(context: childContext)
		
		self.childContext = childContext
		self.childObject = childObject
	}
}

struct UpdateOperation<Object: NSManagedObject>: Identifiable {
	let id = UUID()
	let childContext: NSManagedObjectContext
	let childObject: Object
	
	init?(
		withExistingObject object: Object,
		in parentContext: NSManagedObjectContext
	) {
		let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		childContext.parent = parentContext
		guard let childObject = try? childContext.existingObject(with: object.objectID) as? Object else { return nil }
		
		self.childContext = childContext
		self.childObject = childObject
	}
}
