//
//  LiveCaptureSummary.swift
//  Pagewise
//

import SwiftUI
import os

struct LiveCaptureSummary: View {
	@ObservedObject var capture: ScanCapture
	@Binding var showingMenuFor: ScanRecognizedItem?
	@Binding var editing: Bool

	@State private var showingSignaturePad = false

	var body: some View {
		HStack(alignment: .top, spacing: 12) {

			NavigationLink(destination: QuickLookView(scanCapture: capture)) {
				SmallThumbnail(image: capture.thumbnail)
					.opacity(showingMenuFor == nil ? 1 : 0)
					.animation(.default, value: showingMenuFor)
					.scanFilterMenu(for: capture, onApply: { saveContext() }, onSign: { showingSignaturePad = true })
			}
			.accessibilityLabel("View scan image")

			LazyVStack(alignment: .leading) {

				listOfRecognizedItems
					.opacity(showingMenuFor == nil || showingMenuFor?.parent == capture ? 1 : 0.5)

				Rectangle()
					.fill(Color.clear)
					.frame(height: 1)
			}
		}
		.sheet(isPresented: $showingSignaturePad) {
			SignaturePadView { signatureImage in
				capture.addSignature(signatureImage)
				saveContext()
				Haptics.impact(.light)
			}
		}
	}

	var listOfRecognizedItems: some View {
		VStack {

			if capture.recognizedItemsArray.count > 0 {

				ForEach (capture.recognizedItemsArray, id: \.self) { item in

					RecognizedItemView(item: item, readOnly: false, showingMenuFor: $showingMenuFor, editing: $editing)

				}

			} else {
				Spacer()
			}

		}
	}

	func saveContext() {
		guard let context = capture.managedObjectContext, context.hasChanges else { return }
		do {
			try context.save()
		} catch {
			Logger.app.error("Error saving filtered capture: \(error, privacy: .public)")
		}
	}
}
