//
//  LiveScanSummary.swift
//  Scanmuse
//

import SwiftUI
import VisionKit
import CoreData
import MapKit
import QuickLook
import os

struct LiveScanSummary: View {
	@Environment(\.managedObjectContext) private var viewContext
	@Environment(\.presentationMode) var presentationMode
	
	@ObservedObject var scan: Scan

	@State private var titleValue = ""
	@State private var showTimeline = true
	@State private var showMap = false
	
	@State private var showingMenuFor: ScanRecognizedItem?
	@State private var editing = false

	@State private var captureToSign: ScanCapture?
	@State private var showingSignaturePad = false

	@State private var showingAddTag = false
	@State private var newTagValue = ""

	var body: some View {
		ZStack {
			
			VStack {
				if showMap {
					mapView
				}
				
				if showTimeline {
					
					capturesTimeline
					
				} else {
					
					capturesList
					
				}
				
			}
			
		}
		.background(Color.appBackground)
		.toolbar {
			ToolbarItem(placement: .navigationBarLeading) {
				if AppState.shared.openScan != nil {
					Button { AppState.shared.openScan = nil } label: {
						Label("Scans", systemImage: "chevron.left")
							.labelStyle(.titleAndIcon)
					}
				}
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					if scan.longitude == 0 && scan.latitude == 0 {
						AppState.shared.locationManager.requestLocation()
						if let location = AppState.shared.locationManager.myLocation {
							scan.latitude = location.coordinate.latitude
							scan.longitude = location.coordinate.longitude
							if scan.longitude != 0 && scan.latitude != 0 {
								showMap.toggle()
							}
						}
					} else {
						showMap.toggle()
					}
				} label: {
					Label( "Map", systemImage: "location.square")
						.labelStyle(.iconOnly)
						.foregroundColor(showMap ? Color.white : Color.primary)
						.background(
							RoundedRectangle(cornerRadius: 4)
								.fill(showMap ? Color.accent : Color.clear)
								.padding(-4)
						)
				}
				.accessibilityLabel("Show scan location")
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				Button { showTimeline.toggle() } label: {
					Label( showTimeline ? "Timeline" : "Images", systemImage: showTimeline ? "square.fill.text.grid.1x2" : "square.text.square")
						.labelStyle(.iconOnly)
						.foregroundColor(Color.primary)
				}
				.accessibilityLabel(showTimeline ? "Showing scan timeline" : "Showing scan pages")
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				Menu {
					Button { sharePdf() } label: {
						Label("PDF", systemImage: "doc")
							.labelStyle(.titleAndIcon)
							.font(.title3)
							.foregroundColor(Color.primary)
					}

					Button { shareText() } label: {
						Label("Text", systemImage: "text.alignleft")
							.labelStyle(.titleAndIcon)
							.font(.title3)
							.foregroundColor(Color.primary)
					}

				} label: {
					Label("Share", systemImage: "square.and.arrow.up")
						.labelStyle(.titleAndIcon)
						.foregroundColor(Color.primary)
				}
			}
		}
		.iOSScrollDismissesKeyboard()
		.navigationBarTitleDisplayMode(.inline)
		.ignoresSafeArea(edges: .bottom)
		.sheet(isPresented: $showingSignaturePad) {
			if let captureToSign {
				SignaturePadView { signatureImage in
					captureToSign.addSignature(signatureImage)
					saveContext()
					Haptics.impact(.light)
				}
			}
		}
		.onAppear {
			titleValue = scan.title ?? ""
			showTimeline = scan.isLive
			AppState.shared.requestReviewIfNecessary()
		}
	}
	
	var capturesTimeline: some View {
		ZStack(alignment: .topLeading) {
			
			ScrollView {
				VStack {
					
					scanTitle
						.padding(.leading, isMenuShown ? 100 : 0)
						.animation(.default, value: isMenuShown)
					
					ForEach (scan.capturesArray, id: \.self) { capture in
						
						LiveCaptureSummary(capture: capture, showingMenuFor: $showingMenuFor, editing: $editing)
						
					}
					
					Spacer()
						.frame(height: 340)
				}
				.padding()
			}
			
			overlayMenu
				.padding(.top, 30)
				.padding(.leading, 10)
		}
		
	}
	
	
	var overlayMenu: some View {
		
		
		VStack(alignment: .trailing, spacing: 0) {
			
			Button {
				editing.toggle()
				Haptics.impact(.light)
				if !editing {
					saveContext()
				}
			} label: {
				if editing {
					SummaryContextButton(caption: "Done", image: "checkmark.square", roundTop: true, roundBottom: true)
					
				} else {
					SummaryContextButton(caption: "Edit", image: "character.cursor.ibeam", roundTop: true, roundBottom: false)
					
				}
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0), value: showingMenuFor)
			
			Button {
				guard let item = showingMenuFor else { return }
				shareItem(item: item)
			} label: {
				SummaryContextButton(caption: "Share", image: "square.and.arrow.up")
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown && !editing ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0.03), value: showingMenuFor)

			Button {
				guard let transcript = showingMenuFor?.transcript else { return }
				UIPasteboard.general.setValue(transcript,
											  forPasteboardType: UTType.plainText.identifier)
			} label: {
				SummaryContextButton(caption: "Copy", image: "doc.on.doc")
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown && !editing ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0.06), value: showingMenuFor)

			Button {
				if AppState.shared.isSpeaking {
					AppState.shared.stopSpeaking()
				} else {
					AppState.shared.speak(text: showingMenuFor?.transcript)
				}
			} label: {
				SummaryContextButton(caption: "Speak", image: "mouth")
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown && !editing ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0.09), value: showingMenuFor)

			Button(role: .destructive) {
				guard let item = showingMenuFor else { return }
				viewContext.delete(item)
				showingMenuFor = nil
				saveContext()
				Haptics.impact(.medium)
			} label: {
				SummaryContextButton(caption: "Delete", image: "trash", destructive: true, roundBottom: true)
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown && !editing ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0.12), value: showingMenuFor)
			
			Button { showingMenuFor = nil } label: {
				SummaryContextButton(caption: "Dismiss", image: "xmark", roundTop: true, roundBottom: true, gray: true)
			}
			.offset(x: isMenuShown ? 0 : -100)
			.opacity(isMenuShown && !editing ? 1 : 0)
			.animation(Animation.easeOut(duration: 0.25).delay(0.0), value: showingMenuFor)
			.padding(.top, 30)
			
			
		}
	}
	
	var isMenuShown: Bool {
		showingMenuFor != nil
	}
	
	func shareItem(item: ScanRecognizedItem) {
		guard requirePro() else { return }
		if let url = item.textUrl {
			let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			UIApplication.shared.rootViewControllerForPresenting?.present(activityVC, animated: true, completion: nil)
		}
	}
	
	var capturesList: some View {
		
		List {
			
			scanTitle
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
			
			ForEach (scan.capturesArray, id: \.self) { capture in
				captureClassicThumbnail(capture: capture)
					.padding(.trailing, 32)
					.padding(.bottom, 16)
				
			}
			.onDelete(perform: deleteItems)
			.onMove(perform: moveItems)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			
			Spacer()
				.frame(height: 340)
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
		}
		.listStyle(.plain)
		.ios16scrollContentBackground()
		
	}
	
	func captureClassicThumbnail(capture: ScanCapture) -> some View {
		NavigationLink(destination: QuickLookView(scanCapture: capture)) {
			Image(uiImage: capture.thumbnail ?? UIImage())
				.resizable()
				.scaledToFill()
				.frame(width: 300, height: capture.thumbnail.map { 300 / $0.aspectRatio } ?? 300)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
				.overlay(alignment: .topTrailing) {
					Text("\(capture.order + 1)")
						.font(.caption.bold())
						.foregroundStyle(.white)
						.padding(10)
						.background(Circle().fill(Color.accent))
						.padding(8)
				}
				.scanFilterMenu(for: capture, onApply: { saveContext() }, onSign: {
					captureToSign = capture
					showingSignaturePad = true
				})
		}
	}
	
	var scanTitle: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				TextField("Document title", text: $titleValue)
					.font(.title3.bold())

				if scan.title != titleValue {
					Button {
						scan.title = titleValue
						saveContext()
						Haptics.impact(.light)
					} label: {
						Text("Save")
							.font(.subheadline.bold())
							.foregroundStyle(.white)
							.padding(.horizontal, 14)
							.padding(.vertical, 8)
							.background(Color.accent, in: Capsule())
					}
				}
			}

			tagsRow
		}
		.cardStyle(cornerRadius: 14, padding: 14)
		.alert("Add Tag", isPresented: $showingAddTag) {
			TextField("Tag name", text: $newTagValue)
			Button("Cancel", role: .cancel) { newTagValue = "" }
			Button("Add") {
				scan.addTag(newTagValue)
				newTagValue = ""
				saveContext()
			}
		}
	}

	var tagsRow: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(scan.tags, id: \.self) { tag in
					Button {
						scan.removeTag(tag)
						saveContext()
						Haptics.impact(.light)
					} label: {
						Label(tag, systemImage: "xmark")
							.labelStyle(.titleAndIcon)
							.font(.caption.bold())
					}
					.dataTagModifier()
				}

				Button {
					showingAddTag = true
				} label: {
					Label("Add Tag", systemImage: "plus")
						.labelStyle(.titleAndIcon)
						.font(.caption.bold())
				}
				.dataTagModifier()
				.foregroundStyle(Color.accent)
			}
		}
	}
	
	
	var mapView: some View {
		
		Map(coordinateRegion: .constant(
			MKCoordinateRegion(
				center: CLLocationCoordinate2D(
					latitude: scan.latitude,
					longitude: scan.longitude),
				span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))),
			interactionModes: [MapInteractionModes.all],
			showsUserLocation: true,
			userTrackingMode: .none,
			annotationItems: [scan]) { pin in
			MapAnnotation(
				coordinate: CLLocationCoordinate2D(latitude: scan.latitude, longitude: scan.longitude),
				anchorPoint: CGPoint(x: 0.5, y: 0.5)
			) {
				Image(systemName: "mappin")
					.foregroundColor(Color.red)
					.font(.title)
			}
		}
	}
	
	
	func close() {
		self.presentationMode.wrappedValue.dismiss()
	}
	
	func sharePdf() {
		guard requirePro() else { return }
		if let url = scan.pdfDocumentFile() {
			let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			UIApplication.shared.rootViewControllerForPresenting?.present(activityVC, animated: true, completion: nil)
		}
	}

	func shareText() {
		guard requirePro() else { return }
		if let url = scan.textDocument {
			let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			UIApplication.shared.rootViewControllerForPresenting?.present(activityVC, animated: true, completion: nil)
		}
	}

	/// Gate for the share/export actions — scanning stays free, but getting
	/// a finished document out (PDF, text, or a single recognized item)
	/// requires an active subscription.
	private func requirePro() -> Bool {
		if AppState.shared.isPro { return true }
		AppState.shared.showingPaywall = true
		return false
	}
	
	func shareMarkdown() {
		if let url = scan.textDocument {
			let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			UIApplication.shared.rootViewControllerForPresenting?.present(activityVC, animated: true, completion: nil)
		}
	}
	
	func deleteScan() {
		viewContext.delete(scan)
		saveContext()
		close()
	}
	
	func saveContext() {
		if viewContext.hasChanges {
			do {
				try viewContext.save()
			} catch {
				let nserror = error as NSError
				Logger.app.error("Error saving context: \(nserror, privacy: .public)")
			}
		}
	}
	
	func moveItems(from source: IndexSet, to destination: Int) {
		
		var revisedItems: [ScanCapture] = scan.capturesArray.map{ $0 }
		revisedItems.move(fromOffsets: source, toOffset: destination)
		
		for reverseIndex in stride(
			from: revisedItems.count - 1,
			through: 0,
			by: -1 ) {
			revisedItems[reverseIndex].order = Int32(reverseIndex)
		}
		
		for index in 0..<scan.capturesArray.count {
			scan.capturesArray[index].order = Int32(index)
		}
		
		saveContext()
		scan.lastUpdate = Date()
	}
	
	private func deleteItems(offsets: IndexSet) {
		withAnimation {
			offsets.map { scan.capturesArray[$0] }.forEach(viewContext.delete)

			saveContext()

			for index in 0..<scan.capturesArray.count {
				scan.capturesArray[index].order = Int32(index)
			}

			saveContext()

			scan.lastUpdate = Date()
			Haptics.impact(.medium)
		}
	}
	
	
}
