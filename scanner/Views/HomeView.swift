//
//  HomeView.swift
//  Scanmuse
//

import SwiftUI
import AppIntents
import PhotosUI
import UniformTypeIdentifiers
import os

/// Date-range bucket for filtering the document list, layered on top of the
/// existing text search.
enum ScanDateFilter: String, CaseIterable, Identifiable {
	case any
	case today
	case thisWeek
	case thisMonth

	var id: String { rawValue }

	var title: String {
		switch self {
		case .any: return "Any Time"
		case .today: return "Today"
		case .thisWeek: return "This Week"
		case .thisMonth: return "This Month"
		}
	}

	/// `nil` for `.any` (no date constraint applied to the fetch predicate).
	var dateRange: ClosedRange<Date>? {
		let calendar = Calendar.current
		let now = Date()
		switch self {
		case .any:
			return nil
		case .today:
			return calendar.startOfDay(for: now)...now
		case .thisWeek:
			guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return nil }
			return start...now
		case .thisMonth:
			guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return nil }
			return start...now
		}
	}
}

struct HomeView: View {

	@Environment(\.managedObjectContext) private var viewContext
	@ObservedObject var navigationManager = NavigationManager.shared

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \Scan.order, ascending: false)],
		animation: .default)
	private var scans: FetchedResults<Scan>

	// Unfiltered, so the "Tags" menu always lists every tag in use — even
	// while a search/filter is narrowing what `scans` itself returns.
	@FetchRequest(sortDescriptors: [])
	private var allScansForTags: FetchedResults<Scan>

	@State private var searchText = ""
	@State private var favoritesOnly = false
	@State private var dateFilter: ScanDateFilter = .any
	@State private var selectedTag: String?

	@State var isEditMode: EditMode = .inactive

	// When set (iPad sidebar layout), tapping a row updates this selection
	// instead of pushing via NavigationLink (used for iPhone's stack navigation).
	var selectedScan: Binding<Scan?>? = nil

	@State private var selectedPhotoItems: [PhotosPickerItem] = []
	@State private var showingPhotosPicker = false
	@State private var showingPDFImporter = false
	@State private var showingAbout = false

	var body: some View {
		ZStack {
			Color.clear

			VStack {

				listOfScans
					.ios16scrollContentBackground()

			}

			// Show bottom Start Scan button
			VStack {
				Spacer()
				startScanBottomBar
			}
		}
		// Nothing to search until at least one document exists — the search
		// field only appears once it would actually do something.
		.if(!isTrulyEmpty) { view in
			view.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
		}
		.toolbar {
			ToolbarItem(placement: .navigationBarLeading) {
				Button {
					showingAbout = true
				} label: {
					Image(systemName: "info.circle")
				}
				.accessibilityLabel("About Scanmuse")
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				Menu {
					Button {
						favoritesOnly.toggle()
					} label: {
						Label("Favorites Only", systemImage: favoritesOnly ? "checkmark" : "star")
					}

					Menu {
						ForEach(ScanDateFilter.allCases) { filter in
							Button {
								dateFilter = filter
							} label: {
								Label(filter.title, systemImage: dateFilter == filter ? "checkmark" : "calendar")
							}
						}
					} label: {
						Label("Date", systemImage: "calendar")
					}

					if !availableTags.isEmpty {
						Menu {
							Button {
								selectedTag = nil
							} label: {
								Label("All Tags", systemImage: selectedTag == nil ? "checkmark" : "tag")
							}
							ForEach(availableTags, id: \.self) { tag in
								Button {
									selectedTag = tag
								} label: {
									Label(tag, systemImage: selectedTag == tag ? "checkmark" : "tag")
								}
							}
						} label: {
							Label("Tags", systemImage: "tag")
						}
					}
				} label: {
					Image(systemName: hasStructuredFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
				}
				.accessibilityLabel("Filter documents")
			}

			ToolbarItem(placement: .navigationBarTrailing) {
				Menu {
					Button {
						showingPhotosPicker = true
					} label: {
						Label("Import Photos", systemImage: "photo.on.rectangle")
					}
					Button {
						showingPDFImporter = true
					} label: {
						Label("Import PDF", systemImage: "doc.badge.plus")
					}
				} label: {
					Image(systemName: "square.and.arrow.down")
				}
				.accessibilityLabel("Import")
			}
		}
		.background(Color.appBackground)
		.ignoresSafeArea(edges: .bottom)
		.onChange(of: navigationManager.requestedClassicScan) { newValue in
			guard newValue else { return }
			navigationManager.requestedClassicScan = false
			AppState.shared.viewState = .Page
		}
		.onChange(of: searchText) { _ in
			updateSearchPredicate()
		}
		.onChange(of: favoritesOnly) { _ in
			updateSearchPredicate()
		}
		.onChange(of: dateFilter) { _ in
			updateSearchPredicate()
		}
		.onChange(of: selectedTag) { _ in
			updateSearchPredicate()
		}
		.onChange(of: selectedPhotoItems) { newItems in
			guard !newItems.isEmpty else { return }
			importPhotos(newItems)
		}
		.photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotoItems, matching: .images)
		.fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
			importPDF(result)
		}
		.onAppear {
			if AppState.shared.isSpeaking {
				AppState.shared.stopSpeaking()
			}
		}
		.sheet(isPresented: $showingAbout) {
			NavigationStack {
				ScrollView {
					AboutView()
						.padding()
				}
				.background(Color.appBackground)
				.navigationTitle("About")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { showingAbout = false }
					}
				}
			}
		}
	}

	/// True only for the genuine first-launch state — zero documents and no
	/// active search/filter. Search, stats, and the About footer all assume
	/// there's something to act on, so they're hidden specifically here (as
	/// opposed to `noResultsState`, where a search/filter just narrowed an
	/// existing library to nothing and those controls still make sense).
	private var isTrulyEmpty: Bool {
		scans.isEmpty && !hasActiveFilter
	}

	private func importPhotos(_ items: [PhotosPickerItem]) {
		Task {
			var images: [UIImage] = []
			for item in items {
				if let data = try? await item.loadTransferable(type: Data.self),
				   let image = UIImage(data: data) {
					images.append(image)
				}
			}
			if !images.isEmpty {
				ImportOperations.createScan(fromImages: images, in: viewContext)
				Haptics.success()
			}
			selectedPhotoItems = []
		}
	}

	/// Pushes the search text and any active filters (favorites, date range)
	/// down into the fetch request itself (rather than filtering `scans` in
	/// Swift on every render), so search/filtering stays fast no matter how
	/// many scans are stored.
	private func updateSearchPredicate() {
		var predicates: [NSPredicate] = []

		let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmed.isEmpty {
			// Core Data can't chain ANY across two to-many relationships directly
			// (captures -> recognizedItems); nested SUBQUERY is required instead.
			predicates.append(NSPredicate(
				format: "title CONTAINS[cd] %@ OR SUBQUERY(captures, $c, SUBQUERY($c.recognizedItems, $r, $r.transcript CONTAINS[cd] %@).@count > 0).@count > 0",
				trimmed, trimmed
			))
		}

		if favoritesOnly {
			predicates.append(NSPredicate(format: "fave == YES"))
		}

		if let range = dateFilter.dateRange {
			predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
		}

		if let selectedTag {
			// tagsRaw is stored comma-wrapped (",work,2026,") so this matches a
			// whole tag rather than a substring of a longer one.
			predicates.append(NSPredicate(format: "tagsRaw CONTAINS[cd] %@", ",\(selectedTag),"))
		}

		scans.nsPredicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
	}

	/// Whether the search field or any structured filter would narrow the
	/// list — used to tell "no documents yet" apart from "no matches".
	private var hasActiveFilter: Bool {
		!searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasStructuredFilter
	}

	/// Whether a non-text filter (favorites/date/tag) is active — drives the
	/// filled vs. outline toolbar icon.
	private var hasStructuredFilter: Bool {
		favoritesOnly || dateFilter != .any || selectedTag != nil
	}

	private var availableTags: [String] {
		Array(Set(allScansForTags.flatMap { $0.tags })).sorted()
	}

	private func importPDF(_ result: Result<URL, Error>) {
		switch result {
		case .success(let url):
			let didAccess = url.startAccessingSecurityScopedResource()
			defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
			if ImportOperations.createScan(fromPDF: url, in: viewContext) {
				Haptics.success()
			} else {
				Logger.app.error("PDF import produced no pages (unreadable or empty PDF): \(url, privacy: .public)")
				Haptics.error()
			}
		case .failure(let error):
			Logger.app.error("PDF import failed: \(error, privacy: .public)")
		}
	}
	
	var listOfScans: some View {
		List {
			if scans.isEmpty {
				Group {
					if hasActiveFilter {
						noResultsState
					} else {
						emptyState
					}
				}
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
			} else if searchText.isEmpty {
				statsHeader
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
			}

			ForEach (scans, id: \.self) { scan in

				Group {
					if let selectedScan = selectedScan {
						Button {
							selectedScan.wrappedValue = scan
						} label: {
							scanItem(scan)
						}
						.buttonStyle(CardButtonStyle())
					} else {
						NavigationLink(destination: LiveScanSummary(scan: scan)) {
							scanItem(scan)
						}
						.buttonStyle(CardButtonStyle())
					}
				}
				.swipeActions(edge: .leading) {
					Button {
						scan.fave = !scan.fave
						Haptics.impact(.light)
					} label: {
						Label("Favorite", systemImage: "star")
					}
					.tint(.highlight)
				}
				.swipeActions(edge: .trailing) {
					Button(role: .destructive) {
						viewContext.delete(scan)
						saveContext()
						Haptics.impact(.medium)
					} label: {
						Label("Delete", systemImage: "trash")
					}
				}
				.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
			}
			.onDelete(perform: deleteItems)
			.onMove(perform: moveItems)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)

			Spacer()
				.frame(height: 24)
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)

			// Only once there's an actual library to scroll past — on the
			// true empty state this footer is dead weight below a message
			// that's already telling the user what to do (see `isTrulyEmpty`).
			if !hasActiveFilter && !scans.isEmpty {
				Divider()
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.padding(.horizontal, 40)

				AboutView()
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.padding(.top, 24)
					.padding(.bottom, 100)
					.buttonStyle(.borderless)
			}

		}
		.listStyle(.plain)
		.environment(\.editMode, self.$isEditMode)

	}

	var statsHeader: some View {
		let favoriteCount = scans.filter { $0.fave }.count
		return HStack(spacing: 10) {
			statChip(
				value: "\(scans.count)",
				label: scans.count == 1 ? "Document" : "Documents",
				icon: "doc.text.fill",
				tint: .accent
			)
			if favoriteCount > 0 {
				statChip(
					value: "\(favoriteCount)",
					label: favoriteCount == 1 ? "Favorite" : "Favorites",
					icon: "star.fill",
					tint: .highlight
				)
			}
			Spacer(minLength: 0)
		}
	}

	func statChip(value: String, label: String, icon: String, tint: Color) -> some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.callout)
				.foregroundStyle(tint)
			VStack(alignment: .leading, spacing: 0) {
				Text(value)
					.font(.subheadline.bold())
				Text(label)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.cardStyle(cornerRadius: 12, padding: 10)
	}

	/// The genuine first-launch screen — no search bar, stats, or About
	/// footer competing for attention (see `isTrulyEmpty`), so this owns the
	/// whole canvas and is built to fill it rather than sit as a small
	/// message floating in a lot of leftover white space.
	var emptyState: some View {
		GeometryReader { geo in
			VStack(spacing: 24) {
				ZStack {
					Circle()
						.fill(Color.accent.opacity(0.12))
						.frame(width: 140, height: 140)
					Image(systemName: "doc.text.viewfinder")
						.font(.system(size: 56, weight: .light))
						.foregroundStyle(Color.accent)
						.adaptivePulse()
				}

				VStack(spacing: 8) {
					Text("No documents yet")
						.font(.title2.bold())
					Text("Tap the scan button below to capture your first document.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 40)
				}
			}
			.frame(width: geo.size.width, height: geo.size.height)
		}
		.frame(height: 520)
	}

	var noResultsState: some View {
		VStack(spacing: 14) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 40, weight: .light))
				.foregroundStyle(.secondary)
			Text("No matching documents")
				.font(.title3.bold())
			Text(searchText.isEmpty ? "Try a different filter." : "Try a different word or check the spelling.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 60)
		.padding(.bottom, 24)
	}

	/// A large, full-width "hero" card: the page image dominates, with title,
	/// date, page count and tags anchored below/over it — closer to how
	/// Files/Notes present a document than a compact list row.
	func scanItem(_ scan: Scan) -> some View {
		VStack(alignment: .leading, spacing: 0) {

			heroImage(for: scan)

			VStack(alignment: .leading, spacing: 8) {
				HStack(alignment: .firstTextBaseline, spacing: 6) {
					Text(scan.title?.isEmpty == false ? scan.title! : "Untitled Document")
						.font(.headline)
						.lineLimit(1)
						.foregroundStyle(Color.primary)

					Spacer(minLength: 8)

					Text(scan.timestamp ?? scan.lastUpdate ?? Date(), style: .relative)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				if !scan.tags.isEmpty {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 6) {
							ForEach(scan.tags, id: \.self) { tag in
								Text(tag)
									.font(.caption2.bold())
									.dataTagModifier()
							}
						}
					}
				}
			}
			.padding(14)
		}
		.background(Color.cardBackground)
		.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
		.shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
		.id(scan.lastUpdate)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(scanAccessibilityLabel(scan))
	}

	/// The card's dominant image: the first page at full resolution (crisper
	/// than the list-tile thumbnail this replaced), with favorite/page-count
	/// badges floating over a bottom scrim for legibility on any page.
	func heroImage(for scan: Scan) -> some View {
		let pageCount = scan.capturesArray.count
		let heroHeight: CGFloat = 200

		return ZStack(alignment: .bottom) {
			// A GeometryReader gives us a concrete width to scale against, so
			// the fill-crop can be anchored to the *top* of the page (where a
			// letterhead, heading, or photo usually lives) instead of
			// SwiftUI's default center-crop, which on a tall portrait page
			// mostly just shows a slice of body text.
			GeometryReader { geo in
				if let image = scan.capturesArray.first?.image {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: geo.size.width, height: geo.size.height, alignment: .top)
						.clipped()
				} else {
					ZStack {
						Color.appBackground
						Image(systemName: "doc.text")
							.font(.system(size: 36, weight: .light))
							.foregroundStyle(.tertiary)
					}
					.frame(width: geo.size.width, height: geo.size.height)
				}
			}
			.frame(height: heroHeight)

			LinearGradient(
				colors: [.black.opacity(0.45), .clear],
				startPoint: .bottom,
				endPoint: .center
			)
			.frame(height: heroHeight * 0.6)

			HStack {
				if scan.fave {
					Image(systemName: "star.fill")
						.font(.caption)
						.foregroundStyle(.white)
						.padding(8)
						.background(.ultraThinMaterial, in: Circle())
				}

				Spacer(minLength: 0)

				if pageCount > 0 {
					Text(pageCount == 1 ? "1 page" : "\(pageCount) pages")
						.font(.caption2.bold())
						.foregroundStyle(.white)
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(.ultraThinMaterial, in: Capsule())
				}
			}
			.padding(10)
		}
		.frame(height: heroHeight)
		.accessibilityHidden(true)
	}

	private func scanAccessibilityLabel(_ scan: Scan) -> String {
		var parts: [String] = [scan.title?.isEmpty == false ? scan.title! : "Untitled Document"]
		if scan.fave {
			parts.append("Favorited")
		}
		let pageCount = scan.capturesArray.count
		if pageCount > 0 {
			parts.append(pageCount == 1 ? "1 page" : "\(pageCount) pages")
		}
		let date = scan.timestamp ?? scan.lastUpdate ?? Date()
		parts.append(date.formatted(.relative(presentation: .named)))
		return parts.joined(separator: ", ")
	}

	var startScanBottomBar: some View {
		HStack {
			
			Spacer()
			
			ScanStartPicker()
				.padding()
		}
		.padding(.bottom, 8)
	}
	
	func moveItems(from source: IndexSet, to destination: Int) {
		// `scans` only reflects the full, correctly-ordered list while no
		// search/filter is applied — reordering a filtered subset would
		// corrupt the order of scans currently hidden by the predicate.
		guard !hasActiveFilter else { return }

		var revisedItems: [Scan] = scans.map{ $0 }
		revisedItems.move(fromOffsets: source, toOffset: destination)

		for reverseIndex in stride(
			from: revisedItems.count - 1,
			through: 0,
			by: -1
		) {
			revisedItems[reverseIndex].order = Int32(scans.count - reverseIndex - 1)
		}
		saveContext()
	}

	private func deleteItems(offsets: IndexSet) {
		withAnimation {
			offsets.map { scans[$0] }.forEach(viewContext.delete)
			// Only renumber when unfiltered — see moveItems for why.
			if !hasActiveFilter {
				var i = scans.count - 1
				for scan in scans {
					scan.order = Int32(i)
					i -= 1
				}
			}
			saveContext()
			Haptics.impact(.medium)
		}
	}
	
	func saveContext() {
		if viewContext.hasChanges {
			do {
				try viewContext.save()
			} catch {
				let nserror = error as NSError
				Logger.app.error("Error saving context: \(nserror, privacy: .public)")
			}
		}
	}
	
	func switchView(_ viewState: ViewState) {
		withAnimation(.easeInOut) {
			if AppState.shared.viewState == .About && viewState == .About {
				AppState.shared.viewState = .Home
			} else {
				AppState.shared.viewState = viewState
			}
		}
	}
	
}

struct HomeView_Previews: PreviewProvider {
	static var previews: some View {
		HomeView()
			.environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
	}
}
