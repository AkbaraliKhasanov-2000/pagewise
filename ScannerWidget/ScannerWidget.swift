//
//  ScannerWidget.swift
//  ScannerWidget
//


import WidgetKit
import SwiftUI
import Intents
import CoreData

@main
struct ScannerWidgetBundle: WidgetBundle {

	// MARK: - View
	@WidgetBundleBuilder
	var body: some Widget {
		ClassicScanWidget()
	}
}

struct ClassicScanWidget: Widget {
	let persistenceController = PersistenceController.shared
	let kind: String = "ClassicScannerWidget"
	
	var body: some WidgetConfiguration {
		IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(context: PersistenceController.shared.container.viewContext)) { entry in
			ScannerWidgetEntryView(entry: entry)
				.environment(\.managedObjectContext, persistenceController.container.viewContext)
				.widgetURL(URL(string: "pagewise://scan/classic"))
		}
		.configurationDisplayName("Pagewise")
		.description("See your scan count and jump straight to a new scan.")
		.supportedFamilies([.systemSmall, .accessoryCircular])
	}
}
