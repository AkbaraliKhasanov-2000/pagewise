//
//  AppState.swift
//  Scanmuse
//

import Foundation
import AppIntents
import CoreData
import AVFoundation
import CoreLocation
#if canImport(CoreLocationUI)
import CoreLocationUI
#endif
import StoreKit
import SwiftUI
import os

enum ViewState: String {
	case Home, Page, About
}

extension ViewState: AppEnum {
	static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scanner mode"

	static var caseDisplayRepresentations: [ViewState: DisplayRepresentation] = [
		.Home: "Scan List",
		.Page: "Scan Now",
		.About: "About Scanmuse",
	]
}

class AppState: ObservableObject {

	public static let shared = AppState()
	var locationManager = LocationManager()
	let store = StoreManager()

	@Published var viewState = ViewState.Home {
		didSet {
			stopSpeaking()
		}
	}

	@AppStorage("lastReviewPrompt") private var lastReviewPrompt: Date = Date().addingTimeInterval(TimeInterval(-365*24*60*60))

	@Published var openScan: Scan?
	@Published var openRecognizedItem: ScanRecognizedItem?
	@Published var showingPaywall = false

	private let speechSynthesizer = AVSpeechSynthesizer()

	/// Scanning itself is always free. Sharing or exporting a finished
	/// document (PDF, text, or an individual recognized item) requires an
	/// active Pro subscription — see the `share*` functions in
	/// `LiveScanSummary` for where this is checked.
	var isPro: Bool {
		store.isSubscribed
	}

	var totalScanCount: Int {
		let request = Scan.fetchRequest()
		do {
			return try PersistenceController.shared.container.viewContext.fetch(request).count
		} catch {
			Logger.app.error("Failed to fetch scan count: \(error, privacy: .public)")
			return 0
		}
	}

	var lastScanIndex: Int {
		totalScanCount - 1
	}
	
	func speak(text: String?) {
		guard let text = text else { return }
		
		if speechSynthesizer.isSpeaking {
			speechSynthesizer.stopSpeaking(at: .immediate)
		}
		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

		speechSynthesizer.speak(utterance)
	}
	
	var isSpeaking: Bool {
		return speechSynthesizer.isSpeaking
	}
	
	func stopSpeaking() {
		if speechSynthesizer.isSpeaking {
			speechSynthesizer.stopSpeaking(at: .word)
		}
	}
	
	/// Prompt for a review at most once every 30 days, matching Apple's guidance
	/// against over-prompting. This is the single source of truth for the
	/// review-prompt cadence — call this rather than SKStoreReviewController directly.
	func requestReviewIfNecessary() {
		let daysBetweenReviews = 30.0
		if lastReviewPrompt.addingTimeInterval(TimeInterval(daysBetweenReviews*24*60*60)) < Date() {
			DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
				self.lastReviewPrompt = Date()
				self.requestReview()
			}
		}

	}
	
	func requestReview() {
		#if !os(xrOS)
		SKStoreReviewController.requestReview()
		#endif
	}
}


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	let manager = CLLocationManager()

	@Published var location: CLLocationCoordinate2D?
	private var locations: [CLLocation] = [CLLocation]()

	override init() {
		super.init()
		manager.delegate = self
	}

	func requestLocation() {
		manager.requestWhenInUseAuthorization()
		locationManager(manager, didUpdateLocations: locations)
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		location = locations.first?.coordinate
	}
	
	var myLocation: CLLocation? {
		return manager.location
	}
}
