//
//  LitraKitView.swift
//  LitraKit
//

import UIKit

/// Wraps your `UITextView` and adds word lookup on long press.
///
/// Press and hold → a loupe shows the text under your finger. Release on a word → the
/// word is underlined, your `translator` is asked for a translation, and the result is
/// shown in a bar at the top. LitraKit doesn't lay out, paginate or style the text —
/// that stays with your text view.
///
/// ```swift
/// let litra = LitraKitView(textView: myTextView)
/// litra.translator = MyTranslator()
/// litra.delegate = self
/// ```
public final class LitraKitView: UIView {
    /// The wrapped text view. Configure its text, fonts and insets as usual.
    public let textView: UITextView

    /// Asked for a translation each time a word is selected. Held strongly.
    public var translator: LitraTranslating?

    public weak var delegate: LitraKitDelegate?

    public var configuration: LitraKitConfiguration {
        didSet { applyConfiguration() }
    }

    /// The currently underlined word, if any.
    public private(set) var selectedWord: String?

    private let translationBar = TranslationBar()
    private let loupe = LoupeView()
    private let underline = UnderlineLayer()
    private let requests = TranslationRequestController()
    private lazy var longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    private var selectedRange: NSRange?

    public init(textView: UITextView, configuration: LitraKitConfiguration = LitraKitConfiguration()) {
        self.textView = textView
        self.configuration = configuration
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    /// Removes the underline, hides the bar and cancels a pending translation.
    public func clearSelection() {
        requests.cancel()
        selectedWord = nil
        selectedRange = nil
        refreshUnderline()
        translationBar.show(.hidden)
    }

    // MARK: - Setup

    private func setUp() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        textView.layer.addSublayer(underline)

        translationBar.translatesAutoresizingMaskIntoConstraints = false
        translationBar.onTap = { [weak self] in self?.clearSelection() }
        addSubview(translationBar)

        addSubview(loupe)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            translationBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            translationBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            translationBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        longPress.delegate = self
        textView.addGestureRecognizer(longPress)
        // The text view's own long presses (selection, loupe) and scrolling wait until
        // ours fails, so a held finger always means "look up", never "select" or "scroll".
        for recognizer in textView.gestureRecognizers ?? [] where recognizer !== longPress {
            if recognizer is UILongPressGestureRecognizer || recognizer === textView.panGestureRecognizer {
                recognizer.require(toFail: longPress)
            }
        }

        applyConfiguration()
    }

    private func applyConfiguration() {
        longPress.minimumPressDuration = configuration.minimumPressDuration
        translationBar.apply(configuration)
        loupe.bounds = CGRect(origin: .zero, size: configuration.loupeSize)
        refreshUnderline()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Line breaks may move after a size change; redraw under the same characters.
        refreshUnderline()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshUnderline()
    }

    private func refreshUnderline() {
        underline.update(
            range: selectedRange,
            in: textView,
            color: configuration.underlineColor,
            thickness: configuration.underlineThickness
        )
    }

    // MARK: - Gesture

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let pointInText = gesture.location(in: textView)

        switch gesture.state {
        case .began:
            if configuration.showsLoupe {
                loupe.begin(snapshot: snapshotVisibleText(), magnification: configuration.loupeMagnification)
                moveLoupe(to: pointInText)
            }
        case .changed:
            if configuration.showsLoupe { moveLoupe(to: pointInText) }
        case .ended:
            loupe.end()
            if let found = locateWord(at: pointInText) {
                select(found)
            }
        default:
            loupe.end()
        }
    }

    /// One image of what the text view shows right now; the loupe pans across it.
    private func snapshotVisibleText() -> UIImage {
        let size = textView.bounds.size
        return UIGraphicsImageRenderer(size: size).image { _ in
            textView.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false)
        }
    }

    private func moveLoupe(to pointInText: CGPoint) {
        // Snapshot coordinates = visible part of the text view.
        let pointInSnapshot = CGPoint(
            x: pointInText.x - textView.bounds.minX,
            y: pointInText.y - textView.bounds.minY
        )
        loupe.focus(on: pointInSnapshot)

        let finger = textView.convert(pointInText, to: self)
        let size = configuration.loupeSize
        var center = CGPoint(x: finger.x, y: finger.y - configuration.loupeVerticalOffset - size.height / 2)
        center.x = min(max(center.x, size.width / 2 + 4), bounds.width - size.width / 2 - 4)
        if center.y - size.height / 2 < safeAreaInsets.top {
            // No room above the finger — show it below instead.
            center.y = finger.y + configuration.loupeVerticalOffset + size.height / 2
        }
        loupe.center = center
    }

    // MARK: - Word lookup

    private func locateWord(at point: CGPoint) -> LocatedWord? {
        guard let text = textView.text, !text.isEmpty,
              let position = textView.closestPosition(to: point) else { return nil }
        let offset = textView.offset(from: textView.beginningOfDocument, to: position)

        // `closestPosition` lands between characters; try the character on each side.
        for index in [offset, offset - 1] {
            if let found = WordLocator.word(at: index, in: text), isPoint(point, inside: found.wordRange) {
                return found
            }
        }
        return nil
    }

    /// Guards against picking the nearest word when the finger is on empty space.
    private func isPoint(_ point: CGPoint, inside range: NSRange) -> Bool {
        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end) else { return false }
        return textView.selectionRects(for: textRange).contains { rect in
            rect.rect.insetBy(dx: -4, dy: -4).contains(point)
        }
    }

    private func select(_ found: LocatedWord) {
        selectedWord = found.word
        selectedRange = found.wordRange
        refreshUnderline()
        UISelectionFeedbackGenerator().selectionChanged()

        delegate?.litraKit(self, didSelect: found.word, in: found.sentence)

        guard let translator else {
            requests.cancel()
            translationBar.show(.hidden)
            return
        }

        translationBar.show(.loading(word: found.word))
        requests.request(word: found.word, sentence: found.sentence, translator: translator) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .success(let translation):
                self.translationBar.show(.translated(word: found.word, translation: translation))
                self.delegate?.litraKit(self, didTranslate: found.word, in: found.sentence, translation: translation)
            case .failure(let error):
                self.translationBar.show(.failed(word: found.word, message: error.localizedDescription))
                self.delegate?.litraKit(self, didFailToTranslate: found.word, error: error)
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension LitraKitView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
    }
}
