//
//  LitraKitConfiguration.swift
//  LitraKit
//

import UIKit

/// Appearance and timing. Defaults follow the system look and adapt to dark mode.
public struct LitraKitConfiguration {
    /// Color of the line under the selected word in the text and under the translated
    /// word in the translation strip.
    public var underlineColor: UIColor = .tintColor
    /// Thickness of the underline in the text, in points.
    public var underlineThickness: CGFloat = 2

    /// How long the finger must rest before the loupe appears.
    public var minimumPressDuration: TimeInterval = 0.35

    /// Turn the loupe off entirely.
    public var showsLoupe: Bool = true
    /// How much the loupe enlarges the text under the finger.
    public var loupeMagnification: CGFloat = 1.6
    /// Size of the loupe bubble.
    public var loupeSize: CGSize = CGSize(width: 130, height: 46)
    /// Gap between the finger and the bottom of the loupe.
    public var loupeVerticalOffset: CGFloat = 36

    public init() {}
}
