//
//  LoupeView.swift
//  LitraKit
//

import UIKit

/// Magnifier bubble shown above the finger.
///
/// Works on a single snapshot: the text doesn't change during the gesture, so one image is
/// captured when the press begins and every finger move only shifts `contentsRect` —
/// no re-rendering, no per-frame snapshots.
final class LoupeView: UIView {
    private let contentLayer = CALayer()
    private let clipView = UIView()
    private var snapshotSize: CGSize = .zero
    private var magnification: CGFloat = 1.6

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        clipView.clipsToBounds = true
        clipView.layer.borderWidth = 1 / UIScreen.main.scale
        clipView.layer.borderColor = UIColor.separator.cgColor
        clipView.backgroundColor = .systemBackground
        addSubview(clipView)

        contentLayer.contentsGravity = .resize
        contentLayer.actions = ["contentsRect": NSNull(), "position": NSNull(), "bounds": NSNull()]
        clipView.layer.addSublayer(contentLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clipView.frame = bounds
        clipView.layer.cornerRadius = bounds.height / 2
        contentLayer.frame = clipView.bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath
    }

    func begin(snapshot: UIImage, magnification: CGFloat) {
        contentLayer.contents = snapshot.cgImage
        contentLayer.contentsScale = snapshot.scale
        snapshotSize = snapshot.size
        self.magnification = magnification
        clipView.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
        UIView.animate(withDuration: 0.12) { self.alpha = 1 }
    }

    /// - Parameter point: Finger location in snapshot coordinates.
    func focus(on point: CGPoint) {
        guard snapshotSize.width > 0, snapshotSize.height > 0 else { return }
        let visibleWidth = bounds.width / magnification
        let visibleHeight = bounds.height / magnification
        contentLayer.contentsRect = CGRect(
            x: (point.x - visibleWidth / 2) / snapshotSize.width,
            y: (point.y - visibleHeight / 2) / snapshotSize.height,
            width: visibleWidth / snapshotSize.width,
            height: visibleHeight / snapshotSize.height
        )
    }

    func end() {
        UIView.animate(withDuration: 0.12, animations: { self.alpha = 0 }) { _ in
            if self.alpha == 0 { self.contentLayer.contents = nil }
        }
    }
}
