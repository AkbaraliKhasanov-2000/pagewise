//
//  AboutView.swift
//  Scanmuse
//

import SwiftUI

struct AboutView: View {

	@ObservedObject var store = AppState.shared.store
	@State var justAppeared = true
	@State private var showingPaywall = false
	@State private var showingPrivacyPolicy = false

	var body: some View {
		VStack(alignment: .leading, spacing: 20) {

			HStack(spacing: 14) {
				AppLogoBadge(caption: "SM", exactHeight: 64, justAppeared: $justAppeared)
					.frame(width: 64, height: 64)

				VStack(alignment: .leading, spacing: 2) {
					Text("Scanmuse")
						.font(.system(.title2, design: .rounded, weight: .bold))
					Text("Point, scan, done.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}

			VStack(alignment: .leading, spacing: 12) {
				if store.isSubscribed {
					HStack {
						Image(systemName: "checkmark.seal.fill")
							.foregroundStyle(Color.accent)
							.frame(width: 22)
						Text("Scanmuse Pro is active")
							.foregroundStyle(Color.primary)
						Spacer()
					}
				} else {
					aboutRow(icon: "sparkles", title: "Upgrade to Pro") {
						showingPaywall = true
					}
				}
			}
			.cardStyle(cornerRadius: 14, padding: 14)

			HStack(spacing: 0) {
				Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "•.•") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "•"))")
				Text(" · ")
				Button("Privacy Policy") {
					showingPrivacyPolicy = true
				}
			}
			.font(.footnote)
			.foregroundStyle(.secondary)
		}
		.onAppear {
			withAnimation(.easeOut(duration: 0.5)) {
				justAppeared = false
			}
		}
		.sheet(isPresented: $showingPaywall) {
			PaywallView(store: store)
		}
		.sheet(isPresented: $showingPrivacyPolicy) {
			PrivacyPolicyView()
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
