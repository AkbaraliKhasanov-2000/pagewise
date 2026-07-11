//
//  AboutView.swift
//  DocSnap
//

import SwiftUI

struct AboutView: View {

	@State var justAppeared = true

	static let supportBody: String = "%0A%0A%0A----------%0APlease%20write%20your%20message%20above%20this%20section."

	var body: some View {
		VStack(alignment: .leading, spacing: 20) {

			HStack(spacing: 14) {
				AppLogoBadge(caption: "DOC", exactHeight: 64, justAppeared: $justAppeared)
					.frame(width: 64, height: 64)

				VStack(alignment: .leading, spacing: 2) {
					Text("DocSnap")
						.font(.system(.title2, design: .rounded, weight: .bold))
					Text("Point, scan, done.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}

			VStack(alignment: .leading, spacing: 12) {
				aboutRow(icon: "questionmark.bubble.fill", title: "Need help?") {
					UIApplication.shared.open(
						URL(string: "mailto:support@docsnap.app?subject=DocSnap%20support%20request&body=\(AboutView.supportBody)")!,
						options: [:],
						completionHandler: nil
					)
				}
			}
			.cardStyle(cornerRadius: 14, padding: 14)

			HStack(spacing: 0) {
				Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "•.•") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "•"))")
				Text(" · ")
				Link("Privacy Policy", destination: URL(string: "https://docsnap.app/#privacy")!)
			}
			.font(.footnote)
			.foregroundStyle(.secondary)
		}
		.onAppear {
			withAnimation(.easeOut(duration: 0.5)) {
				justAppeared = false
			}
		}
	}

	private func aboutRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack {
				Image(systemName: icon)
					.foregroundStyle(Color.accent)
					.frame(width: 22)
				Text(title)
					.foregroundStyle(Color.primary)
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
			.contentShape(Rectangle())
		}
	}
}

struct AboutView_Previews: PreviewProvider {
	static var previews: some View {
		AboutView()
	}
}
