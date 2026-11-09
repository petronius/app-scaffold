import SwiftUI

/// The app's named colours: one colour, one meaning (`spec/DESIGN-STYLE.md`).
/// Every colour a view uses comes from here or from the system's semantic
/// colours (`.primary`, `.secondary`, the grouped backgrounds), never a
/// literal in a view. Each value lives in the asset catalogue with a light
/// and a dark appearance.
enum Palette {
    /// The accent: the primary action and the selection. The catalogue's
    /// `AccentColor`, so every untinted control uses it too.
    static let accent = Color.accentColor

    /// A warning, and nothing else.
    static let attention = Color("Attention")

    /// The background wash behind a chip or a tile, as a shared opacity
    /// rather than a value picked per view. `strongWash` marks a chosen one.
    static let wash = 0.12
    static let strongWash = 0.24
}
