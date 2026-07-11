//
//  scannerTests.swift
//  scannerTests
//

import XCTest
import PDFKit
import UIKit
@testable import scanner

final class scannerTests: XCTestCase {

	func testSearchablePDFExportContainsRecognizableText() throws {
		let persistence = PersistenceController(inMemory: true)
		let context = persistence.container.viewContext

		let scan = Scan(context: context)
		scan.createDefaults()

		let capture = ScanCapture(context: context)
		capture.id = UUID()
		capture.timestamp = Date()
		capture.order = 0

		let textImage = Self.makeTextImage(text: "HELLO SCAN")
		capture.createImage(fullSizedImage: textImage)
		capture.createThumbnail(fullSizedImage: textImage)
		scan.addToCaptures(capture)

		let pdf = scan.pdfDocument()
		XCTAssertEqual(pdf.pageCount, 1)

		let pageText = pdf.page(at: 0)?.string ?? ""
		XCTAssertTrue(
			pageText.uppercased().contains("HELLO"),
			"Expected the PDF's invisible OCR text layer to contain 'HELLO', got: \"\(pageText)\""
		)
	}

	func testImportFromImagesCreatesScanWithOCRText() throws {
		let persistence = PersistenceController(inMemory: true)
		let context = persistence.container.viewContext

		let textImage = Self.makeTextImage(text: "IMPORTED PAGE")
		ImportOperations.createScan(fromImages: [textImage], in: context)

		let scans = try context.fetch(Scan.fetchRequest())
		XCTAssertEqual(scans.count, 1)

		let scan = try XCTUnwrap(scans.first)
		XCTAssertEqual(scan.capturesArray.count, 1)

		let transcript = scan.capturesArray.first?.recognizedItemsArray
			.compactMap { $0.transcript }.joined(separator: " ") ?? ""
		XCTAssertTrue(
			transcript.uppercased().contains("IMPORTED"),
			"Expected imported page's OCR transcript to contain 'IMPORTED', got: \"\(transcript)\""
		)
	}

	func testImportFromPDFRendersPagesAndRunsOCR() throws {
		let persistence = PersistenceController(inMemory: true)
		let context = persistence.container.viewContext

		let pdfURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("scannerTests-\(UUID().uuidString).pdf")
		let pageBounds = CGRect(x: 0, y: 0, width: 800, height: 400)
		let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
		let data = renderer.pdfData { context in
			context.beginPage()
			UIColor.white.setFill()
			UIBezierPath(rect: pageBounds).fill()
			let attributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.boldSystemFont(ofSize: 60),
				.foregroundColor: UIColor.black
			]
			("PDF TEXT" as NSString).draw(at: CGPoint(x: 40, y: 140), withAttributes: attributes)
		}
		try data.write(to: pdfURL)
		defer { try? FileManager.default.removeItem(at: pdfURL) }

		ImportOperations.createScan(fromPDF: pdfURL, in: context)

		let scans = try context.fetch(Scan.fetchRequest())
		XCTAssertEqual(scans.count, 1)

		let scan = try XCTUnwrap(scans.first)
		XCTAssertEqual(scan.capturesArray.count, 1)

		let transcript = scan.capturesArray.first?.recognizedItemsArray
			.compactMap { $0.transcript }.joined(separator: " ") ?? ""
		XCTAssertTrue(
			transcript.uppercased().contains("PDF"),
			"Expected imported PDF page's OCR transcript to contain 'PDF', got: \"\(transcript)\""
		)
	}

	func testSearchPredicateMatchesTitleAndOCRTextOnly() throws {
		let persistence = PersistenceController(inMemory: true)
		let context = persistence.container.viewContext

		let titleMatch = Scan(context: context)
		titleMatch.id = UUID()
		titleMatch.timestamp = Date()
		titleMatch.title = "Alpha Invoice"

		let bodyMatch = Scan(context: context)
		bodyMatch.id = UUID()
		bodyMatch.timestamp = Date()
		bodyMatch.title = "Untitled"
		let capture = ScanCapture(context: context)
		capture.id = UUID()
		capture.timestamp = Date()
		let item = ScanRecognizedItem(context: context)
		item.id = UUID()
		item.timestamp = Date()
		item.transcript = "Contains the word Alpha in the body"
		capture.addToRecognizedItems(item)
		bodyMatch.addToCaptures(capture)

		let noMatch = Scan(context: context)
		noMatch.id = UUID()
		noMatch.timestamp = Date()
		noMatch.title = "Beta Notes"

		try context.save()

		let request = Scan.fetchRequest()
		request.predicate = NSPredicate(
			format: "title CONTAINS[cd] %@ OR SUBQUERY(captures, $c, SUBQUERY($c.recognizedItems, $r, $r.transcript CONTAINS[cd] %@).@count > 0).@count > 0",
			"alpha", "alpha"
		)
		let results = try context.fetch(request)

		XCTAssertEqual(Set(results.map { $0.objectID }), Set([titleMatch.objectID, bodyMatch.objectID]))
		XCTAssertFalse(results.contains { $0.objectID == noMatch.objectID })
	}

	/// Renders a large, high-contrast block of text so Vision's OCR reliably recognizes it in a test.
	private static func makeTextImage(text: String) -> UIImage {
		let size = CGSize(width: 800, height: 400)
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { _ in
			UIColor.white.setFill()
			UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

			let attributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.boldSystemFont(ofSize: 80),
				.foregroundColor: UIColor.black
			]
			(text as NSString).draw(at: CGPoint(x: 40, y: 140), withAttributes: attributes)
		}
	}

}
