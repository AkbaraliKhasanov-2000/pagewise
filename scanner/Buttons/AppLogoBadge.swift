//
//  AppLogoBadge.swift
//  Pagewise
//

import SwiftUI

/// Pagewise's mark: a rounded badge with a folded-corner page cut into one
/// corner, over a blue-to-amber brand gradient. Pops in with a fade + scale
/// rather than sliding shapes in from off-screen.
struct AppLogoBadge: View {

	@State var caption: String = ""
	@State var image: String = ""
	var size: ContentSizeCategory = .small
	var exactHeight: CGFloat = 0
	var outline: Bool = true
	@Binding var justAppeared: Bool

	var height: CGFloat {
		if exactHeight > 0 {
			return exactHeight
		} else {
			switch size {
			case .small: return 60
			case .medium: return 100
			case .large: return 140
			default: return 100
			}
		}
	}

	var body: some View {
		GeometryReader { geometry in
			let side = min(geometry.size.width, geometry.size.height)
			let foldSize = side * 0.32
			let cornerRadius = side * 0.22

			ZStack(alignment: .topTrailing) {
				LinearGradient(
					colors: [Color.accent, Color.highlight],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)

				// Folded page corner, cut into the top-trailing edge.
				Path { path in
					path.move(to: CGPoint(x: side - foldSize, y: 0))
					path.addLine(to: CGPoint(x: side, y: 0))
					path.addLine(to: CGPoint(x: side, y: foldSize))
					path.closeSubpath()
				}
				.fill(Color.black.opacity(0.16))

				Text(caption)
					.font(.system(size: side * 0.3, weight: .bold, design: .rounded))
					.foregroundColor(.white)
					.frame(width: geometry.size.width, height: geometry.size.height)
			}
			.frame(width: geometry.size.width, height: geometry.size.height)
			.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(Color.primary.opacity(0.15), lineWidth: outline ? 1 : 0)
			)
			.scaleEffect(justAppeared ? 0.7 : 1)
			.opacity(justAppeared ? 0 : 1)
		}
		.frame(height: height)
		.animation(.bouncy(duration: 0.5).delay(0.15), value: justAppeared)
	}
}
