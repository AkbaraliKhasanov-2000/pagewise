//
//  WidgetView.swift
//  ScannerWidgetExtension
//

import SwiftUI
import WidgetKit

struct ScannerWidgetEntryView: View {

	@Environment(\.widgetFamily) var widgetFamily

	var entry: Provider.Entry

	var body: some View {
		switch widgetFamily {
		case .systemSmall:
			// Small home screen widget: scan count + start-a-scan affordance
			ZStack {
				Color.appBackground
				VStack(spacing: 6) {
					Image(systemName: "doc.viewfinder")
						.symbolRenderingMode(.palette)
						.foregroundStyle(Color.accent, Color.highlight)
						.font(.system(size: 34, weight: .light))
					Text(caption)
						.font(.caption)
						.bold()
						.multilineTextAlignment(.center)
						.lineLimit(2)
						.padding(.horizontal, 4)
				}
			}
		case .accessoryCircular:
			// Small circular lock screen widget
			ZStack {
				AccessoryWidgetBackground()
				VStack(spacing: 0) {
					Image(systemName: "doc.viewfinder")
						.font(.system(size: 20))
					if entry.totalCount > 0 {
						Text("\(entry.totalCount)")
							.font(.system(size: 12, weight: .bold))
					}
				}
			}
		default:
			ZStack {
			}
		}
	}

	var caption: String {
		switch entry.totalCount {
		case 0: return "Start scanning"
		case 1: return "1 scan"
		default: return "\(entry.totalCount) scans"
		}
	}

}

