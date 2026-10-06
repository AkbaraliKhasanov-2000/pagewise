//
//  ViewExtensions.swift
//  Scanmuse
//

import Foundation
import SwiftUI
import LinkPresentation
import UIKit
import ImageIO
import CoreImage
import CoreImage.CIFilterBuiltins
import PencilKit
import os

extension Logger {
	/// Single shared logger for the app — visible in Console.app under this subsystem/category.
	static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.akbaralikhasanov.pagewise", category: "app")
}

enum Haptics {
	static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
		UIImpactFeedbackGenerator(style: style).impactOccurred()
	}

	static func success() {
		UINotificationFeedbackGenerator().notificationOccurred(.success)
	}

	static func error() {
		UINotificationFeedbackGenerator().notificationOccurred(.error)
	}
}

extension UIApplication {
	/// The root view controller of the active foreground scene, for presenting
	/// sheets (e.g. share sheets) from non-view contexts. Scene-aware, so it
	/// works correctly with multiple windows/scenes (iPad, Stage Manager).
	var rootViewControllerForPresenting: UIViewController? {
		connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }?
			.windows
			.first { $0.isKeyWindow }?
			.rootViewController
	}
}

public extension Color {

	static let background = Color("background")
	static let foreground = Color("foreground")
	static let accent = Color("accent")
	static let highlight = Color("highlight")

	/// The page canvas — a neutral, system-adaptive grouped background.
	static let appBackground = Color(uiColor: .systemGroupedBackground)
	/// An elevated surface (card/row) sitting on top of `appBackground`.
	static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

	init(hex: UInt, alpha: Double = 1) {
		self.init(
			.sRGB,
			red: Double((hex >> 16) & 0xff) / 255,
			green: Double((hex >> 08) & 0xff) / 255,
			blue: Double((hex >> 00) & 0xff) / 255,
			opacity: alpha
		)
	}
}

/// Shared card styling: rounded, elevated surface with a soft shadow — the
/// base visual language reused across scan rows, buttons, and panels.
struct CardStyle: ViewModifier {
	var cornerRadius: CGFloat = 16
	var padding: CGFloat = 16

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.background(Color.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
			.shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
	}
}

extension View {
	func cardStyle(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
		modifier(CardStyle(cornerRadius: cornerRadius, padding: padding))
	}
}

/// A subtle press-down effect for tappable cards/rows, replacing the flat
/// `.plain` button style so taps feel tactile rather than inert.
struct CardButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.97 : 1)
			.opacity(configuration.isPressed ? 0.85 : 1)
			.animation(.easeOut(duration: 0.15), value: configuration.isPressed)
	}
}

extension View {
	/// A gentle looping pulse on SF Symbols, iOS 17+ only (no-op on iOS 16).
	@ViewBuilder
	func adaptivePulse() -> some View {
		if #available(iOS 17.0, *) {
			self.symbolEffect(.pulse)
		} else {
			self
		}
	}
}

func getDocumentsDirectory() -> URL {
	let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
	return paths[0]
}

func getTemporaryDirectory() -> URL {
	let previewURL = FileManager.default.temporaryDirectory.appendingPathComponent("Document")
	return previewURL
}

class ShareImage: UIActivityItemProvider {
	var image: UIImage
	
	override var item: Any {
		get {
			return self.image
		}
	}
	
	override init(placeholderItem: Any) {
		self.image = placeholderItem as? UIImage ?? UIImage()
		super.init(placeholderItem: placeholderItem)
	}
	
	@available(iOS 13.0, *)
	override func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
		
		let metadata = LPLinkMetadata()
		metadata.title = "Result Image"
		
		var thumbnail: NSSecureCoding = NSNull()
		if let imageData = self.image.pngData() {
			thumbnail = NSData(data: imageData)
		}
		
		metadata.imageProvider = NSItemProvider(item: thumbnail, typeIdentifier: "public.png")
		
		return metadata
	}
	
}

extension Animation {
	func `repeat`(while expression: Bool, autoreverses: Bool = true) -> Animation {
		if expression {
			return self.repeatForever(autoreverses: autoreverses)
		} else {
			return self
		}
	}
}

/// Scan quality/appearance filters applied to a captured page image.
public enum ScanImageFilter: String, CaseIterable, Identifiable {
	case original
	case enhanced
	case grayscale
	case blackAndWhite

	public var id: String { rawValue }

	var title: String {
		switch self {
		case .original: return "Original"
		case .enhanced: return "Enhanced"
		case .grayscale: return "Grayscale"
		case .blackAndWhite: return "Black & White"
		}
	}

	var icon: String {
		switch self {
		case .original: return "photo"
		case .enhanced: return "wand.and.stars"
		case .grayscale: return "circle.lefthalf.filled"
		case .blackAndWhite: return "circle.righthalf.filled"
		}
	}

	/// Applies the filter to `image`, returning a new image. `.original` returns
	/// the image unchanged (it's the escape hatch back to the pristine capture).
	func apply(to image: UIImage) -> UIImage {
		guard self != .original, let cgImage = image.cgImage else { return image }

		let input = CIImage(cgImage: cgImage)
		let context = CIContext()
		let output: CIImage

		switch self {
		case .original:
			return image
		case .enhanced:
			let filter = CIFilter.colorControls()
			filter.inputImage = input
			filter.contrast = 1.25
			filter.saturation = 1.05
			filter.brightness = 0.02
			output = filter.outputImage ?? input
		case .grayscale:
			let filter = CIFilter.photoEffectMono()
			filter.inputImage = input
			output = filter.outputImage ?? input
		case .blackAndWhite:
			// Push toward a real high-contrast "paper scan" look rather than a
			// soft grayscale — desaturate, then crank contrast so text goes
			// near-black and the page background goes near-white.
			let filter = CIFilter.colorControls()
			filter.inputImage = input
			filter.saturation = 0
			filter.contrast = 2.2
			filter.brightness = 0.1
			output = filter.outputImage ?? input
		}

		guard let outputCGImage = context.createCGImage(output, from: input.extent) else { return image }
		return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
	}
}

extension UIImage {

	var aspectRatio: CGFloat {
		size.width / size.height
	}
	
	func resizeToWidth(_ width: CGFloat) -> UIImage {
		
		// Determine the scale factor that preserves aspect ratio
		let ratio = size.width / size.height
		let height = width / ratio
		
		// Compute the new image size that preserves aspect ratio
		let scaledImageSize = CGSize(
			width: width,
			height: height
		)
		
		// Draw and return the resized UIImage
		
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		
		let renderer = UIGraphicsImageRenderer(size: scaledImageSize, format: format)
		
		let scaledImage = renderer.image { _ in
			self.draw(in: CGRect(
				origin: .zero,
				size: scaledImageSize
			))
		}
		
		return scaledImage
	}
	
	/// Draws `signature` (a transparent-background ink image) over the
	/// bottom-trailing corner of this image, scaled to `widthFraction` of
	/// the page width so it reads consistently across page sizes.
	func compositingSignature(_ signature: UIImage, widthFraction: CGFloat = 0.32, margin: CGFloat = 24) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let renderer = UIGraphicsImageRenderer(size: size, format: format)

		return renderer.image { _ in
			self.draw(in: CGRect(origin: .zero, size: size))

			let sigWidth = size.width * widthFraction
			let sigHeight = sigWidth / signature.aspectRatio
			let rect = CGRect(
				x: size.width - sigWidth - margin,
				y: size.height - sigHeight - margin,
				width: sigWidth,
				height: sigHeight
			)
			signature.draw(in: rect)
		}
	}

	func resize(newSize: CGSize) -> UIImage? {
		let renderer = UIGraphicsImageRenderer(size: newSize)
		return renderer.image { (context) in
			self.draw(in: CGRect(origin: .zero, size: newSize))
		}
	}
	
}

struct FlippedUpsideDown: ViewModifier {
	func body(content: Content) -> some View {
		content
			.rotationEffect(.radians(CGFloat.pi))
			.scaleEffect(x: -1, y: 1, anchor: .center)
	}
}
extension View {
	func flippedUpsideDown() -> some View{
		self.modifier(FlippedUpsideDown())
	}
}

extension String {
	func truncate(to limit: Int) -> String {
		if count > limit {
			let truncated = String(prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
			return truncated + "\u{2026}"
		} else {
			return self
		}
	}
	
	func sanitized() -> String {
		// see for ressoning on charachrer sets https://superuser.com/a/358861
		let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
			.union(.newlines)
			.union(.illegalCharacters)
			.union(.controlCharacters)
		
		return String(
			self
				.components(separatedBy: invalidCharacters)
				.joined(separator: "")
				.prefix(50)
		)
	}
	
	mutating func sanitize() -> Void {
		self = self.sanitized()
	}
	
	func whitespaceCondensed() -> String {
		return self.components(separatedBy: .whitespacesAndNewlines)
			.filter { !$0.isEmpty }
			.joined(separator: " ")
	}
	
	mutating func condenseWhitespace() -> Void {
		self = self.whitespaceCondensed()
	}
}

extension View {
	/// Applies the given transform if the given condition evaluates to `true`.
	/// - Parameters:
	///   - condition: The condition to evaluate.
	///   - transform: The transform to apply to the source `View`.
	/// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
	@ViewBuilder func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
		if condition() {
			transform(self)
		} else {
			self
		}
	}
}

struct ScrollContentBackgroundHiddenModifier: ViewModifier {
	
	func body(content: Content) -> some View {
		content
			.scrollContentBackground(.hidden)
	}
}

struct ScrollDismissesKeyboardInteractivelyModifier: ViewModifier {
	
	func body(content: Content) -> some View {
		content
#if !os(xrOS)
			.scrollDismissesKeyboard(.interactively)
#endif
	}
}

extension View {

	@ViewBuilder
	func ios16scrollContentBackground() -> some View {
		self
			.modifier(ScrollContentBackgroundHiddenModifier())
	}
	
	@ViewBuilder
	func iOSScrollDismissesKeyboard() -> some View {
		self
			.modifier(ScrollDismissesKeyboardInteractivelyModifier())
	}
	
	@ViewBuilder
	func dataTagModifier() -> some View {
		self
			.modifier(DataTagModifier())
	}

	/// Applies a real Liquid Glass effect on iOS 26+, falling back to a
	/// translucent material with a hairline border on earlier versions.
	@ViewBuilder
	func adaptiveGlassBackground<S: Shape>(in shape: S) -> some View {
		if #available(iOS 26.0, *) {
			self.glassEffect(.regular, in: shape)
		} else {
			self
				.background(.regularMaterial, in: shape)
				.overlay(shape.stroke(Color.primary.opacity(0.15), lineWidth: 1))
		}
	}
}

extension View {
	/// Long-press menu offering scan quality filters (Original/Enhanced/
	/// Grayscale/Black & White) for a single captured page, applied in place.
	/// Pass `onSign` to also offer an "Add Signature…" entry.
	func scanFilterMenu(for capture: ScanCapture, onApply: @escaping () -> Void = {}, onSign: (() -> Void)? = nil) -> some View {
		self.contextMenu {
			ForEach(ScanImageFilter.allCases) { filter in
				Button {
					capture.applyFilter(filter)
					Haptics.impact(.light)
					onApply()
				} label: {
					Label(filter.title, systemImage: capture.currentFilter == filter ? "checkmark" : filter.icon)
				}
			}

			if let onSign {
				Divider()
				Button {
					onSign()
				} label: {
					Label("Add Signature…", systemImage: "signature")
				}
			}
		}
	}
}

/// A signature-drawing sheet backed by PencilKit. Renders the finished
/// drawing as a transparent-background image via `onSave`, ready to be
/// composited onto a page.
struct SignaturePadView: View {
	@Environment(\.dismiss) private var dismiss
	var onSave: (UIImage) -> Void

	@State private var canvasView = PKCanvasView()
	@State private var isEmpty = true

	var body: some View {
		NavigationStack {
			SignatureCanvas(canvasView: $canvasView, isEmpty: $isEmpty)
				.background(Color.white)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.15), lineWidth: 1))
				.padding()
				.background(Color.appBackground)
				.navigationTitle("Sign")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") { dismiss() }
					}
					ToolbarItem(placement: .navigationBarLeading) {
						Button("Clear") {
							canvasView.drawing = PKDrawing()
							isEmpty = true
						}
						.disabled(isEmpty)
					}
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							onSave(renderSignatureImage())
							dismiss()
						}
						.disabled(isEmpty)
					}
				}
		}
	}

	private func renderSignatureImage() -> UIImage {
		let drawing = canvasView.drawing
		let rect = drawing.bounds.insetBy(dx: -12, dy: -12)
		return drawing.image(from: rect, scale: UIScreen.main.scale)
	}
}

private struct SignatureCanvas: UIViewRepresentable {
	@Binding var canvasView: PKCanvasView
	@Binding var isEmpty: Bool

	func makeUIView(context: Context) -> PKCanvasView {
		canvasView.drawingPolicy = .anyInput
		canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
		canvasView.backgroundColor = .clear
		canvasView.delegate = context.coordinator
		return canvasView
	}

	func updateUIView(_ uiView: PKCanvasView, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(isEmpty: $isEmpty)
	}

	final class Coordinator: NSObject, PKCanvasViewDelegate {
		@Binding var isEmpty: Bool

		init(isEmpty: Binding<Bool>) {
			_isEmpty = isEmpty
		}

		func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
			isEmpty = canvasView.drawing.strokes.isEmpty
		}
	}
}

struct DataTagModifier: ViewModifier {

	func body(content: Content) -> some View {
		content
			.padding(.vertical, 4)
			.padding(.horizontal, 8)
			.font(.footnote)
			.lineLimit(1)
			.adaptiveGlassBackground(in: Capsule())

	}
}

extension Date: RawRepresentable {
	private static let formatter = ISO8601DateFormatter()
	
	public var rawValue: String {
		Date.formatter.string(from: self)
	}
	
	public init?(rawValue: String) {
		self = Date.formatter.date(from: rawValue) ?? Date()
	}
}
