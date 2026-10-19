//
//  UnderlineLayer.swift
//  LitraKit
//

import UIKit

/// Draws the underline as a layer on top of the text view instead of editing its
/// attributed text — the consumer's styling is never touched. Lives in the text view's
/// content coordinates, so it scrolls with the text for free.
final class UnderlineLayer: CAShapeLayer {
    override init() {
        super.init()
        fillColor = nil
        lineCap = .round
        zPosition = 1
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Underlines `range` (UTF-16) of `textView`'s text; `nil` clears.
    func update(range: NSRange?, in textView: UITextView, color: UIColor, thickness: CGFloat) {
        guard let range,
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end) else {
            path = nil
            return
        }

        let path = UIBezierPath()
        for rect in textView.selectionRects(for: textRange).map(\.rect) where rect.width > 0 {
            let y = rect.maxY - thickness
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        strokeColor = color.resolvedColor(with: textView.traitCollection).cgColor
        lineWidth = thickness
        self.path = path.cgPath
    }
}
