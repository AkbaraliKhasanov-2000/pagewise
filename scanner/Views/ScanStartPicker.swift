//
//  ScanStartPicker.swift
//  Scanmuse
//

import SwiftUI

struct ScanStartPicker: View {

	var body: some View {
		Button {
			switchView(.Page)
		} label: {
			Image(systemName: "plus.viewfinder")
				.symbolRenderingMode(.palette)
				.foregroundStyle(Color.primary, Color.highlight)
				.font(.system(size: 40, weight: .light))
				.padding(16)
		}
		.accessibilityLabel("Start scanning")
		.adaptiveGlassBackground(in: Capsule())
	}
	
	func switchView(_ viewState: ViewState) {
		withAnimation(.easeInOut) {
			AppState.shared.viewState = viewState
		}
	}
	
}

struct ScanStartPicker_Previews: PreviewProvider {
	static var previews: some View {
		ScanStartPicker()
	}
}
