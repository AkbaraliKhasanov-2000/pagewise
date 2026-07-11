//
//  PageScan.swift
//  DocSnap
//

import SwiftUI
import Vision
import VisionKit

struct PageScan: View {
	@Environment(\.managedObjectContext) private var viewContext
	
	@ObservedObject var viewModel = CameraScanViewModel()
	
	@State var documentTitle: String = "Document"
	@State var showScanOnInit = true
	
	@State var isEditMode: EditMode = .active
	
	@State var scan: Scan?
	
	var body: some View {
		ZStack {
		}
		.onAppear {
			if showScanOnInit {
				showScanOnInit = false
				startScan()
			} else {
				AppState.shared.viewState = .Home
			}
			
		}
	}
	
	func startScan() {
		UIApplication.shared.rootViewControllerForPresenting?.present(
			viewModel.getDocumentCameraViewController(),
			animated: true,
			completion: nil)
	}
	
	func moveItems(from source: IndexSet, to destination: Int) {
		viewModel.imageArray.move(fromOffsets: source, toOffset: destination)
	}
	
	private func deleteItems(offsets: IndexSet) {
		withAnimation {
			viewModel.imageArray.remove(atOffsets: offsets)
		}
	}
}
