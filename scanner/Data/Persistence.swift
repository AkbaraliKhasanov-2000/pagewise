//
//  Persistence.swift
//  Pagewise
//

import CoreData
import os

struct PersistenceController {
	static let shared = PersistenceController()
	
	private (set) var spotlightIndexer: NSCoreDataCoreSpotlightDelegate?
	
	let container: NSPersistentCloudKitContainer
	
	init(inMemory: Bool = false) {
		container = NSPersistentCloudKitContainer(name: "scanner")
		
		guard let description = container.persistentStoreDescriptions.first else {
			fatalError("###\(#function): Failed to retrieve a persistent store description.")
		}
		
		description.type = NSSQLiteStoreType
		description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
		description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
		
		if inMemory {
			// Preview and in memory experiments
			description.url = URL(fileURLWithPath: "/dev/null")
			description.cloudKitContainerOptions = nil
		} else if let sharedStoreURL = FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akbaralikhasanov.pagewise")?
			.appendingPathComponent("scanner.sqlite") {
			// Store inside the shared App Group container (not just the app's own
			// sandbox) so the widget extension can read the same data directly,
			// without waiting on CloudKit sync.
			description.url = sharedStoreURL
		}
		
		// Captured as a local (rather than through self) so it can be reused from the
		// escaping completion handler below without capturing struct self.
		let cloudContainer = container

		cloudContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error = error as NSError? {
				Logger.app.error("Error loading persistent store: \(error, privacy: .public)")

				// Many load failures are transient (e.g. the file-protected store
				// isn't readable yet right after boot, or the shared App Group
				// container isn't ready immediately after install) and succeed on
				// a second attempt. Retry once *without* destroying anything first,
				// so a transient error doesn't cost the user their whole library.
				cloudContainer.loadPersistentStores(completionHandler: { (retryDescription, retryError) in
					guard let retryError = retryError as NSError? else { return }
					Logger.app.error("Retry failed, recovering by recreating the store: \(retryError, privacy: .public)")

					// Still failing — the store is genuinely unusable (e.g. corrupted
					// or failed migration). Destroy it and start fresh once, rather
					// than crashing the app on every future launch.
					guard let url = retryDescription.url else { return }
					try? cloudContainer.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
					cloudContainer.loadPersistentStores(completionHandler: { (_, finalError) in
						if let finalError = finalError as NSError? {
							Logger.app.error("Persistent store could not be recovered: \(finalError, privacy: .public)")
						}
					})
				})
			}
		})
		
		spotlightIndexer = NSCoreDataCoreSpotlightDelegate(
			forStoreWith: description,
			coordinator: container.persistentStoreCoordinator
		)
		spotlightIndexer?.startSpotlightIndexing()
		
		if !inMemory {
			// Permanent store options
			container.viewContext.automaticallyMergesChangesFromParent = true
			container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		}
	}
	
	func scanFromUri(_ uri: URL) -> Scan? {
		guard let objectID = container.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri)
		else {
			return nil
		}
		return container.viewContext.object(with: objectID) as? Scan
	}
	
	func recognizedItemFromUri(_ uri: URL) -> ScanRecognizedItem? {
		guard let objectID = container.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri)
		else {
			return nil
		}
		return container.viewContext.object(with: objectID) as? ScanRecognizedItem
	}
	
	static var preview: PersistenceController = {
		let result = PersistenceController(inMemory: true)
		let viewContext = result.container.viewContext
		for _ in 0..<2 {
			let newScan = Scan(context: viewContext)
			newScan.timestamp = Date()
			for _ in 0..<4 {
				let newPage = ScanCapture(context: viewContext)
				newPage.timestamp = Date()
				for index in 0..<3 {
					let newItem = ScanRecognizedItem(context: viewContext)
					newItem.timestamp = Date()
					newItem.transcript = "Transcript \(index)"
				}
			}
		}
		do {
			try viewContext.save()
		} catch {
			// Replace this implementation with code to handle the error appropriately.
			// fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			let nsError = error as NSError
			fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
		}
		return result
	}()
	
}
