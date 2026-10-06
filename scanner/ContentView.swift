//
//  ContentView.swift
//  Scanmuse
//

import SwiftUI
import CoreData

struct ContentView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@StateObject var loading = AppState.shared

	// Selected scan for the iPad sidebar+detail layout only; iPhone continues
	// to use push navigation via NavigationLink, driven by AppState.openScan.
	@State private var selectedScan: Scan?

	var body: some View {
		Group {
			if horizontalSizeClass == .regular {
				iPadContent
			} else {
				iPhoneContent
			}
		}
		.onAppear {
			ScannerShortcuts.updateAppShortcutParameters()
		}
		.sheet(isPresented: $loading.showingPaywall) {
			PaywallView(store: loading.store)
		}
	}

	var iPhoneContent: some View {
		NavigationStack {

			ZStack(alignment: .center) {

				switch AppState.shared.viewState {
				case .Home, .About:
					if let scan = AppState.shared.openScan {
						// Open a scan linked from the outside
						LiveScanSummary(scan: scan)
					} else {
						// Open standard Home screen
						HomeView()
							.transition(.move(edge: .bottom))
					}
				case .Page:
					PageScan()
						.transition(.opacity)
				}

				if AppState.shared.viewState == .About {
					Color.black.opacity(0.2)
						.transition(.opacity)
						.ignoresSafeArea(.all)
						.onTapGesture {
							withAnimation {
								AppState.shared.viewState = .Home
							}
						}
					AboutView()
						.zIndex(1)
						.transition(.opacity)
				}

			}

			.navigationTitle("Documents")
			.navigationBarTitleDisplayMode(.automatic)
			.background(Color.appBackground,
						ignoresSafeAreaEdges: [.all]
			)
		}
	}

	var iPadContent: some View {
		NavigationSplitView {
			HomeView(selectedScan: $selectedScan)
				.navigationTitle("Documents")
				.background(Color.appBackground, ignoresSafeAreaEdges: [.all])
		} detail: {
			Group {
				if AppState.shared.viewState == .Page {
					PageScan()
				} else if let scan = AppState.shared.openScan ?? selectedScan {
					LiveScanSummary(scan: scan)
				} else {
					emptyDetailPlaceholder
				}
			}
			.background(Color.appBackground, ignoresSafeAreaEdges: [.all])
		}
		.onChange(of: AppState.shared.openScan) { newValue in
			if let newValue {
				selectedScan = newValue
			}
		}
	}

	var emptyDetailPlaceholder: some View {
		VStack(spacing: 12) {
			Image(systemName: "doc.text.viewfinder")
				.font(.system(size: 56, weight: .light))
				.foregroundStyle(.secondary)
			Text("No document selected")
				.font(.title3.bold())
			Text("Pick one from the list, or start a new scan.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 40)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}


struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
	}
}
