//
//  TimelineEntry.swift
//  ScannerWidgetExtension
//

import Foundation
import WidgetKit

struct ScanArrayEntry: TimelineEntry {
	let date: Date
	let configuration: ConfigurationIntent
	let entries: [ScanEntry]
	let totalCount: Int
}

struct ScanEntry {
	let title: String?
}
