//
//  StripBackgroundView.swift
//  LitraKit
//

import UIKit

/// Solid backdrop behind the translation strip that fades out at its bottom edge.
///
/// It starts at the top of `LitraKitView` (behind the status bar), so there is no seam
/// between the status bar area and the strip, and scrolled text doesn't show through.
final class StripBackgroundView: UIView {
    /// Height of the fade at the bottom edge, in points.
    static let fadeHeight: CGFloat = 16

    var color: UIColor = .systemBackground {
        didSet { backgroundColor = color }
    }

    private let fadeMask = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        backgroundColor = color
        fadeMask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        layer.mask = fadeMask
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeMask.frame = bounds
        let solidEnd = bounds.height > 0 ? max(0, 1 - Self.fadeHeight / bounds.height) : 0
        fadeMask.locations = [0, NSNumber(value: Double(solidEnd)), 1]
        CATransaction.commit()
    }
}
