//
//  Fonts.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import SwiftUI
import CoreText

// Registers the bundled custom fonts with the system at launch.
// Required because the target uses a generated Info.plist with no
// UIAppFonts entry — without this, Font.custom(...) silently falls
// back to the system font.
enum LayaFontRegistration {
    // Resource file names (without extension), as they sit in Laya/Fonts.
    private static let fileNames = [
        "AnticDidone-Regular",
        "Inter_18pt-Bold",
        "Inter_18pt-ExtraLight",
        "Inter_18pt-Light",
        "Inter_18pt-Medium",
        "Inter_18pt-Regular",
        "Inter_18pt-SemiBold"
    ]

    private static var didRegister = false

    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true
        for name in fileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    // MARK: — Antic Didone (display)
    static func layaDisplay(_ size: CGFloat) -> Font {
        .custom("AnticDidone-Regular", size: size)
    }

    // MARK: — Inter (UI)
    static func layaBody(_ size: CGFloat, weight: LayaFontWeight = .regular) -> Font {
        .custom(weight.interFontName, size: size)
    }
}

// Inter weight mapping — keeps call sites clean
enum LayaFontWeight {
    case light
    case regular
    case medium
    case semibold

    var interFontName: String {
        switch self {
        case .light:    return "Inter18pt-Light"
        case .regular:  return "Inter18pt-Regular"
        case .medium:   return "Inter18pt-Medium"
        case .semibold: return "Inter18pt-SemiBold"
        }
    }
}

// MARK: — Semantic text style modifiers
extension View {
    // Chapter titles, artist name, wordmark
    func layaTitle(_ size: CGFloat = 28) -> some View {
        self.font(.layaDisplay(size))
    }

    // Standard body copy
    func layaBodyStyle(_ size: CGFloat = 13, weight: LayaFontWeight = .light) -> some View {
        self.font(.layaBody(size, weight: weight))
            .foregroundStyle(.textPrimary)
    }
}
