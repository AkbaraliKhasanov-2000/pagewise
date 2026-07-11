//
//  NavigationManager.swift
//  DocSnap
//

import Foundation

class NavigationManager: ObservableObject {
	static let shared = NavigationManager()

	@Published var requestedLiveScan: Bool = false
	@Published var requestedClassicScan: Bool = false

	func openApp() {
		// Open to Scans view
	}
	func openClassic() {
		DispatchQueue.main.async {
			self.requestedClassicScan = true
		}
	}
}
