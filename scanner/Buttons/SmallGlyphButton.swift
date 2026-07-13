//
//  SmallGlyphButton.swift
//  Pagewise
//

import SwiftUI

struct SmallThumbnail: View {

	var image: UIImage?
	var size: CGSize = CGSize(width: 80, height: 80)

	var body: some View {
		ZStack {
			if image != nil {
				Image(uiImage: image ?? UIImage())
					.resizable()
					.scaledToFill()
					.frame(width: size.width, height: size.height)
					.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
			} else {
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(Color.appBackground)
			}
		}
		.frame(width: size.width, height: size.height)
		.shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
	}
}

struct SmallThumbnail_Previews: PreviewProvider {
	static var previews: some View {
		SmallThumbnail(image: nil)
	}
}
