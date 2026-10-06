//
//  QuickLookController.swift
//  Scanmuse
//

import SwiftUI
import UIKit
import QuickLook
import os

struct QuickLookView: View {
	@Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
	@State var scanCapture: ScanCapture
	
	var body: some View {
		ZStack(alignment: .top) {
			QuickLookController(scanCapture: scanCapture)
				.navigationBarHidden(true)
				.ignoresSafeArea(edges: .all)
			
			HStack {

				buttonBack
				Spacer()
			}
			.padding(.horizontal)
			.padding(.top, 6)
		}
	}
	
	var buttonBack: some View {
		Button {
			presentationMode.wrappedValue.dismiss()
		} label: {
			HStack(spacing: 4) {
				Image(systemName: "chevron.left")
				Text("Back")
			}
			.font(.body.weight(.semibold))
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.adaptiveGlassBackground(in: Capsule())
		}
	}
	
}

struct QuickLookController: UIViewControllerRepresentable {
	
	var scanCapture: ScanCapture
	
	func makeUIViewController(context: Context) -> UINavigationController {
		let controller = QLPreviewController()
		controller.dataSource = context.coordinator
		controller.delegate = context.coordinator
		controller.setEditing(true, animated: true)
		let navigationController = UINavigationController(rootViewController: controller)
		return navigationController
	}
	
	func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	class Coordinator: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
		
		let parent: QuickLookController
		
		init(parent: QuickLookController) {
			self.parent = parent
		}
		
		func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
		
		func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode { .updateContents }
		
		func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
			
			var url: URL? = nil
			let data: Data = self.parent.scanCapture.imageData ?? Data()
			url = imageUrl
			do {
				try data.write(to: url!)
			} catch {
				Logger.app.error("Failed to write scan image for QuickLook: \(error, privacy: .public)")
			}
			
			let previewItem = ScanPreview(url: url, title: "Scan")
			return previewItem as QLPreviewItem
		}
		
		func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
			
			do {
				let imageData = try Data(contentsOf: imageUrl)
				parent.scanCapture.imageData = imageData
				parent.scanCapture.parent?.lastUpdate = Date()
				parent.scanCapture.createThumbnail()
				// This markup edit becomes the new baseline, so a later filter
				// application doesn't regenerate the page from the stale
				// pre-markup original and silently discard the edit.
				parent.scanCapture.commitAsOriginal()
				saveContext()
			} catch {
				Logger.app.error("Failed to load edited scan image: \(error, privacy: .public)")
			}
		}
		
		var imageUrl: URL {
			getDocumentsDirectory().appendingPathComponent((self.parent.scanCapture.id?.uuidString ?? "scan") + ".jpg")
		}
		
		func saveContext() {
			let viewContext = PersistenceController.shared.container.viewContext
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
}

class ScanPreview: NSObject, QLPreviewItem {
	
	var previewItemURL: URL?
	var previewItemTitle: String?
	
	init(url: URL?, title: String?) {
		previewItemURL = url
		previewItemTitle = title
	}
}
