//
//  TimelineProvider.swift
//  ScannerWidgetExtension
//


import WidgetKit
import Intents
import CoreData
import SwiftUI

struct Provider: IntentTimelineProvider {
	
	var viewContext : NSManagedObjectContext

	init(context : NSManagedObjectContext) {
		self.viewContext = context
	}
	
	func placeholder(in context: Context) -> ScanArrayEntry {
		createEntry()
	}

	func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (ScanArrayEntry) -> ()) {
		let entry = createEntry()
		completion(entry)
	}

	func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<ScanArrayEntry>) -> ()) {

		try? viewContext.setQueryGenerationFrom(.current)
		viewContext.refreshAllObjects()

		let request = NSFetchRequest<Scan>(entityName: "Scan")
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Scan.order, ascending: false)]

		let scans = (try? viewContext.fetch(request)) ?? []
		let entry = createEntry(scans, configuration: configuration)
		let timeline = Timeline(entries: [entry], policy: .atEnd)
		completion(timeline)

	}

	func createEntry(_ scans: [Scan] = [], configuration: ConfigurationIntent? = nil) -> ScanArrayEntry {
		let entries = scans.prefix(5).map { ScanEntry(title: $0.title) }
		return ScanArrayEntry(
			date: Date(),
			configuration: configuration ?? ConfigurationIntent(),
			entries: Array(entries),
			totalCount: scans.count
		)
	}
}
