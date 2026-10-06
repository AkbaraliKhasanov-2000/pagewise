//
//  StoreManager.swift
//  Scanmuse
//

import Foundation
import StoreKit
import os

/// Owns the app's Pro subscriptions (weekly and monthly, one group): loads their StoreKit products,
/// tracks whether the user currently holds an active entitlement, and
/// exposes purchase/restore actions. `AppState.shared.store` is the one
/// instance the rest of the app reads from.
///
/// The class itself isn't globally `@MainActor` (that would force
/// `AppState`'s synchronous init — and everything that touches it — onto
/// the main actor too). Instead, each function that mutates `@Published`
/// state is individually `@MainActor`, so those mutations are still
/// main-thread-safe for SwiftUI without constraining construction.
final class StoreManager: ObservableObject {

	static let weeklyProductID = "com.akbaralikhasanov.pagewise.pro.weekly"
	static let monthlyProductID = "com.akbaralikhasanov.pagewise.pro.monthly"
	private static let allProductIDs: Set<String> = [weeklyProductID, monthlyProductID]

	@Published private(set) var weeklyProduct: Product?
	@Published private(set) var monthlyProduct: Product?
	@Published private(set) var isSubscribed = false
	@Published private(set) var isLoadingProducts = false
	@Published var lastErrorMessage: String?

	private var transactionListenerTask: Task<Void, Never>?

	init() {
		transactionListenerTask = listenForTransactionUpdates()
		Task {
			await loadProducts()
			await refreshEntitlement()
		}
	}

	deinit {
		transactionListenerTask?.cancel()
	}

	@MainActor
	func loadProducts() async {
		isLoadingProducts = true
		defer { isLoadingProducts = false }
		do {
			let products = try await Product.products(for: Self.allProductIDs)
			weeklyProduct = products.first { $0.id == Self.weeklyProductID }
			monthlyProduct = products.first { $0.id == Self.monthlyProductID }
		} catch {
			Logger.app.error("Failed to load StoreKit products: \(error, privacy: .public)")
			lastErrorMessage = "Couldn't load subscription options. Check your connection and try again."
		}
	}

	/// Re-derives `isSubscribed` from StoreKit's on-device entitlement
	/// records — the source of truth StoreKit itself maintains, so this
	/// stays correct across renewals, cancellations, and restores without
	/// the app needing its own server.
	@MainActor
	func refreshEntitlement() async {
		var hasActiveSubscription = false
		for await result in Transaction.currentEntitlements {
			guard case .verified(let transaction) = result else { continue }
			if Self.allProductIDs.contains(transaction.productID) && transaction.revocationDate == nil {
				hasActiveSubscription = true
			}
		}
		isSubscribed = hasActiveSubscription
	}

	@MainActor
	func purchase(_ product: Product?) async {
		guard let product else {
			lastErrorMessage = "Subscription isn't available right now. Please try again shortly."
			return
		}
		do {
			let result = try await product.purchase()
			switch result {
			case .success(let verification):
				if case .verified(let transaction) = verification {
					await transaction.finish()
					await refreshEntitlement()
					Haptics.success()
				}
			case .userCancelled:
				break
			case .pending:
				lastErrorMessage = "Your purchase is pending approval."
			@unknown default:
				break
			}
		} catch {
			Logger.app.error("Purchase failed: \(error, privacy: .public)")
			lastErrorMessage = "Purchase failed. Please try again."
		}
	}

	@MainActor
	func restorePurchases() async {
		do {
			try await AppStore.sync()
			await refreshEntitlement()
			if !isSubscribed {
				lastErrorMessage = "No active subscription found for this Apple ID."
			}
		} catch {
			Logger.app.error("Restore failed: \(error, privacy: .public)")
			lastErrorMessage = "Couldn't restore purchases. Please try again."
		}
	}

	private func listenForTransactionUpdates() -> Task<Void, Never> {
		Task.detached { [weak self] in
			for await result in Transaction.updates {
				guard case .verified(let transaction) = result else { continue }
				await transaction.finish()
				await self?.refreshEntitlement()
			}
		}
	}
}
