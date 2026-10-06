//
//  PaywallView.swift
//  Scanmuse
//

import SwiftUI
import StoreKit

/// The subscription screen shown whenever a non-subscribed user tries to
/// share or export a finished document (scanning itself is always free —
/// see `LiveScanSummary.requirePro()`), or opened voluntarily from About.
/// Purchases and restores go through `AppState.shared.store` (StoreKit 2) —
/// this view only reflects its state.
struct PaywallView: View {
	@Environment(\.dismiss) private var dismiss
	@ObservedObject var store: StoreManager

	@State private var isPurchasing = false
	@State private var isRestoring = false
	@State private var showingErrorAlert = false
	@State private var selectedPlan: Plan = .weekly

	private enum Plan {
		case weekly, monthly

		var title: String { self == .weekly ? "Weekly" : "Monthly" }
		var periodWord: String { self == .weekly ? "week" : "month" }
		var renewalWord: String { self == .weekly ? "weekly" : "monthly" }
	}

	private func product(for plan: Plan) -> Product? {
		plan == .weekly ? store.weeklyProduct : store.monthlyProduct
	}

	/// The product the subscribe button acts on — the selected plan, or the
	/// other one if StoreKit only returned a single product.
	private var selectedProduct: Product? {
		product(for: selectedPlan) ?? store.weeklyProduct ?? store.monthlyProduct
	}

	private var effectivePlan: Plan {
		selectedProduct?.id == StoreManager.monthlyProductID ? .monthly : .weekly
	}

	private static let benefits: [(icon: String, title: String, subtitle: String)] = [
		("doc.richtext", "Export as PDF", "Save a searchable, text-selectable PDF of any document."),
		("square.and.arrow.up", "Share anywhere", "Send finished documents via Mail, Messages, or any app."),
		("text.alignleft", "Export as text", "Get a plain-text copy of everything you've scanned."),
		("icloud", "iCloud sync", "Your library follows you across every device.")
	]

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 28) {
					VStack(spacing: 10) {
						Image(systemName: "doc.text.viewfinder")
							.font(.system(size: 44, weight: .light))
							.foregroundStyle(Color.accent)

						Text("Scanmuse Pro")
							.font(.system(.title, design: .rounded, weight: .bold))

						Text("Subscribe to Scanmuse Pro to share or export this document.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 24)
					}
					.padding(.top, 12)

					VStack(spacing: 14) {
						ForEach(Self.benefits, id: \.title) { benefit in
							HStack(spacing: 14) {
								Image(systemName: benefit.icon)
									.font(.title3)
									.foregroundStyle(Color.accent)
									.frame(width: 32)

								VStack(alignment: .leading, spacing: 2) {
									Text(benefit.title)
										.font(.subheadline.bold())
									Text(benefit.subtitle)
										.font(.footnote)
										.foregroundStyle(.secondary)
								}

								Spacer(minLength: 0)
							}
						}
					}
					.cardStyle(cornerRadius: 18, padding: 16)
					.padding(.horizontal)

					planPicker
						.padding(.horizontal)

					subscribeButton
						.padding(.horizontal)

					Button {
						Task {
							isRestoring = true
							await store.restorePurchases()
							isRestoring = false
							if store.lastErrorMessage != nil {
								showingErrorAlert = true
							}
						}
					} label: {
						if isRestoring {
							ProgressView()
						} else {
							Text("Restore Purchases")
						}
					}
					.font(.subheadline)
					.disabled(isRestoring || isPurchasing)

					Text("Auto-renews \(effectivePlan.renewalWord) until canceled. Cancel anytime in Settings.")
						.font(.caption2)
						.foregroundStyle(.tertiary)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 40)

					HStack(spacing: 16) {
						Link("Privacy Policy", destination: URL(string: "https://akbaralikhasanov.github.io/pagewise/privacy.html")!)
						Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
					}
					.font(.caption2)
				}
				.padding(.bottom, 24)
			}
			.background(Color.appBackground)
			.navigationTitle("Upgrade")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Not Now") { dismiss() }
				}
			}
			.task {
				if store.weeklyProduct == nil && store.monthlyProduct == nil {
					await store.loadProducts()
				}
			}
			.onChange(of: store.isSubscribed) { isSubscribed in
				if isSubscribed { dismiss() }
			}
			.alert("Something went wrong", isPresented: $showingErrorAlert, presenting: store.lastErrorMessage) { _ in
				Button("OK", role: .cancel) {}
			} message: { message in
				Text(message)
			}
		}
	}

	@ViewBuilder
	private var planPicker: some View {
		VStack(spacing: 10) {
			ForEach([Plan.weekly, Plan.monthly], id: \.title) { plan in
				if let product = product(for: plan) {
					planRow(plan, product: product)
				}
			}
		}
	}

	private func planRow(_ plan: Plan, product: Product) -> some View {
		let isSelected = effectivePlan == plan
		return Button {
			selectedPlan = plan
		} label: {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(plan.title)
						.font(.subheadline.bold())
					Text("\(product.displayPrice) per \(plan.periodWord)")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.foregroundStyle(isSelected ? Color.accent : Color.secondary)
			}
			.padding(14)
			.background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(isSelected ? Color.accent : Color.clear, lineWidth: 2)
			)
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder
	private var subscribeButton: some View {
		Button {
			Task {
				isPurchasing = true
				await store.purchase(selectedProduct)
				isPurchasing = false
				if store.lastErrorMessage != nil {
					showingErrorAlert = true
				}
			}
		} label: {
			HStack {
				Spacer()
				if isPurchasing {
					ProgressView()
						.tint(.white)
				} else if let product = selectedProduct {
					Text("Subscribe — \(product.displayPrice)/\(effectivePlan.periodWord)")
						.font(.headline)
				} else if store.isLoadingProducts {
					ProgressView()
						.tint(.white)
				} else {
					Text("Subscribe")
						.font(.headline)
				}
				Spacer()
			}
			.foregroundStyle(.white)
			.padding(.vertical, 14)
			.background(Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		}
		.disabled(isPurchasing || isRestoring || selectedProduct == nil)
	}
}

struct PaywallView_Previews: PreviewProvider {
	static var previews: some View {
		PaywallView(store: StoreManager())
	}
}
