//
//  TranslationBar.swift
//  LitraKit
//

import UIKit

/// The strip at the top that shows the translation of the selected word.
final class TranslationBar: UIView {
    enum State: Equatable {
        case hidden
        case loading(word: String)
        case translated(word: String, translation: String)
        case failed(word: String, message: String)
    }

    var onTap: (() -> Void)?

    private let blur = UIVisualEffectView()
    private let translationLabel = UILabel()
    private let wordLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private(set) var state: State = .hidden

    override init(frame: CGRect) {
        super.init(frame: frame)
        alpha = 0
        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently

        blur.clipsToBounds = true
        blur.layer.cornerRadius = 14
        blur.layer.cornerCurve = .continuous
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        translationLabel.numberOfLines = 2
        translationLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        wordLabel.numberOfLines = 1
        wordLabel.setContentHuggingPriority(.required, for: .horizontal)
        wordLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [spinner, translationLabel, wordLabel])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ configuration: LitraKitConfiguration) {
        blur.effect = UIBlurEffect(style: configuration.barBlurStyle)
        translationLabel.font = configuration.barFont
        translationLabel.adjustsFontForContentSizeCategory = true
        translationLabel.textColor = configuration.barTextColor
        wordLabel.font = configuration.barFont
        wordLabel.adjustsFontForContentSizeCategory = true
        wordLabel.textColor = configuration.barSecondaryTextColor
    }

    func show(_ state: State) {
        self.state = state
        switch state {
        case .hidden:
            spinner.stopAnimating()
        case .loading(let word):
            spinner.startAnimating()
            translationLabel.text = word
            translationLabel.alpha = 0.5
            wordLabel.text = nil
        case .translated(let word, let translation):
            spinner.stopAnimating()
            translationLabel.text = translation
            translationLabel.alpha = 1
            wordLabel.text = word
        case .failed(let word, let message):
            spinner.stopAnimating()
            translationLabel.text = message
            translationLabel.alpha = 1
            wordLabel.text = word
        }
        wordLabel.isHidden = wordLabel.text == nil
        accessibilityLabel = [translationLabel.text, wordLabel.text].compactMap { $0 }.joined(separator: ", ")

        let visible = state != .hidden
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.alpha = visible ? 1 : 0
            self.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: -8)
        }
        if visible {
            UIAccessibility.post(notification: .announcement, argument: accessibilityLabel)
        }
    }

    @objc private func tapped() {
        onTap?()
    }
}
