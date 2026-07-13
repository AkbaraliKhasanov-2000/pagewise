//
//  PrivacyPolicyView.swift
//  Pagewise
//

import SwiftUI

struct PrivacyPolicyView: View {
	@Environment(\.dismiss) private var dismiss

	private struct Section {
		let title: String
		let body: String
	}

	private let sections: [Section] = [
		Section(
			title: "What Pagewise stores",
			body: "Every document you scan or import — its pages, recognized text, tags, and any signature you add — is stored in a private database on your device. Pagewise does not run its own servers and never sees your documents."
		),
		Section(
			title: "iCloud sync",
			body: "If you're signed in to iCloud, your documents sync across your own devices using Apple's CloudKit, inside your personal iCloud account. This data stays within your iCloud account and is never accessible to us."
		),
		Section(
			title: "Text recognition",
			body: "Scanned pages are processed with Apple's on-device Vision framework. Recognition happens entirely on your device — page images and text are never uploaded to any server for OCR."
		),
		Section(
			title: "Subscriptions",
			body: "Pagewise Pro purchases are handled entirely by Apple through StoreKit. We don't receive or store your payment details — Apple manages billing according to its own privacy policy."
		),
		Section(
			title: "Analytics & tracking",
			body: "Pagewise does not include any analytics, advertising, or tracking SDKs, and does not share your data with third parties."
		),
		Section(
			title: "Contact",
			body: "Questions about this policy can be sent to support@pagewise.app."
		)
	]

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					ForEach(sections, id: \.title) { section in
						VStack(alignment: .leading, spacing: 6) {
							Text(section.title)
								.font(.headline)
							Text(section.body)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
				}
				.padding()
			}
			.navigationTitle("Privacy Policy")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

struct PrivacyPolicyView_Previews: PreviewProvider {
	static var previews: some View {
		PrivacyPolicyView()
	}
}
