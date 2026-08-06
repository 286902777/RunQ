import CoreText
import OSLog
import UIKit

enum BundledFontRegistrar {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RunQ",
        category: "Fonts"
    )

    private static let fontFileNames = [
        "Barlow-Black", "Barlow-BlackItalic", "Barlow-Bold",
        "Barlow-BoldItalic", "Barlow-ExtraBold",
        "Barlow-ExtraBoldItalic", "Barlow-ExtraLight",
        "Barlow-ExtraLightItalic", "Barlow-Italic", "Barlow-Light",
        "Barlow-LightItalic", "Barlow-Medium", "Barlow-MediumItalic",
        "Barlow-Regular", "Barlow-SemiBold", "Barlow-SemiBoldItalic",
        "Barlow-Thin", "Barlow-ThinItalic", "PassionOne-Black",
        "PassionOne-Bold", "PassionOne-Regular"
    ]

    @MainActor
    static func registerFonts() {
        fontFileNames.forEach(registerFont)
    }

    private static func registerFont(named fileName: String) {
        guard let fontURL = bundledFontURL(named: fileName) else {
            logger.error("Bundled font is missing: \(fileName, privacy: .public).ttf")
            return
        }
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(
            fontURL as CFURL,
            .process,
            &error
        )
        if !registered, UIFont(name: fileName, size: 12) == nil {
            let detail = error?.takeRetainedValue().localizedDescription
                ?? "Unknown font registration error"
            logger.error("Unable to register \(fileName, privacy: .public): \(detail, privacy: .public)")
        }
    }

    private static func bundledFontURL(named fileName: String) -> URL? {
        let directories: [String?] = [
            "Resources/Fonts/Barlow", "Resources/Fonts/PassionOne",
            "Fonts/Barlow", "Fonts/PassionOne", "Barlow", "PassionOne", nil
        ]
        return directories.lazy.compactMap {
            Bundle.main.url(
                forResource: fileName,
                withExtension: "ttf",
                subdirectory: $0
            )
        }.first
    }
}

enum AppFont {
    static func barlow(
        size: CGFloat,
        weight: UIFont.Weight = .regular
    ) -> UIFont {
        let name: String
        switch weight {
        case .medium: name = "Barlow-Medium"
        case .semibold: name = "Barlow-SemiBold"
        case .bold: name = "Barlow-Bold"
        case .black: name = "Barlow-Black"
        default: name = "Barlow-Regular"
        }
        return UIFont(name: name, size: size)
            ?? .systemFont(ofSize: size, weight: weight)
    }

    static func passionOne(
        size: CGFloat,
        weight: UIFont.Weight = .bold
    ) -> UIFont {
        UIFont(
            name: weight == .bold ? "PassionOne-Bold" : "PassionOne-Regular",
            size: size
        ) ?? .systemFont(ofSize: size, weight: weight)
    }
}
