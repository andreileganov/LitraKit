//
//  LitraKitView.swift
//  LitraKit
//

import SwiftUI
import UIKit

/// Wraps your `UITextView` and adds word lookup on long press.
///
/// Press and hold → a loupe shows the text under your finger. Release on a word → the
/// word is underlined, your `translator` is asked for a translation, and the result is
/// shown in a strip at the top: the translated sentence with the word centered. LitraKit doesn't lay out, paginate or style the text —
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

    private let strip = StripModel()
    private lazy var stripHost = UIHostingController(rootView: SentenceTranslationStripHost(model: strip))
    private let stripBackground = StripBackgroundView()
    private let loupe = LoupeView()
    private let underline = UnderlineLayer()
    private let requests = TranslationRequestController()
    private lazy var longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
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

    /// Removes the underline, hides the strip and cancels a pending translation.
    public func clearSelection() {
        requests.cancel()
        selectedWord = nil
        selectedRange = nil
        refreshUnderline()
        setStripState(nil)
    }

    // MARK: - Setup

    private func setUp() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        textView.layer.addSublayer(underline)

        // Covers the text behind the strip, from the very top (behind the status bar)
        // down to the strip, so scrolled text never shows through.
        stripBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stripBackground)

        let stripView = stripHost.view!
        stripView.backgroundColor = .clear
        stripView.isUserInteractionEnabled = false
        stripView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stripView)

        addSubview(loupe)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stripView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            stripView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Row height (30) + top padding (4) from SentenceTranslationStrip.
            stripView.heightAnchor.constraint(equalToConstant: 34),
            stripBackground.topAnchor.constraint(equalTo: topAnchor),
            stripBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            stripBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            stripBackground.bottomAnchor.constraint(
                equalTo: stripView.bottomAnchor, constant: StripBackgroundView.fadeHeight
            ),
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

        // Like Litra's reader: a tap anywhere dismisses the strip.
        tap.cancelsTouchesInView = false
        tap.require(toFail: longPress)
        textView.addGestureRecognizer(tap)

        applyConfiguration()
    }

    private func applyConfiguration() {
        longPress.minimumPressDuration = configuration.minimumPressDuration
        strip.accent = Color(configuration.underlineColor)
        loupe.bounds = CGRect(origin: .zero, size: configuration.loupeSize)
        refreshUnderline()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Line breaks may move after a size change; redraw under the same characters.
        refreshUnderline()
        stripBackground.color = textView.backgroundColor ?? .systemBackground
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshUnderline()
    }

    /// Every strip change goes through here so the background fades together with the
    /// strip (same duration and curve Litra's reader uses for the strip).
    private func setStripState(_ state: StripState?) {
        strip.state = state
        let visible = state != nil
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.stripBackground.alpha = visible ? 1 : 0
        }
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
        // Like the system loupe: follow the finger horizontally, but keep the line under
        // the finger vertically centered so the text never sits at the bubble's edge.
        var focusY = pointInText.y
        if let position = textView.closestPosition(to: pointInText) {
            let caret = textView.caretRect(for: position)
            if caret.height > 0, abs(caret.midY - pointInText.y) < caret.height * 1.5 {
                focusY = caret.midY
            }
        }
        // Snapshot coordinates = visible part of the text view.
        let pointInSnapshot = CGPoint(
            x: pointInText.x - textView.bounds.minX,
            y: focusY - textView.bounds.minY
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

    /// Same as Litra's reader: a tap hides the strip and cancels the pending request.
    /// The underline stays.
    @objc private func handleTap() {
        guard strip.state != nil else { return }
        requests.cancel()
        setStripState(nil)
    }

    private func select(_ found: LocatedWord) {
        selectedWord = found.word
        selectedRange = found.wordRange
        refreshUnderline()
        UISelectionFeedbackGenerator().selectionChanged()

        delegate?.litraKit(self, didSelect: found.word, in: found.sentence)

        guard let translator else {
            requests.cancel()
            setStripState(nil)
            return
        }

        setStripState(.loading(word: found.word))
        requests.request(word: found.word, sentence: found.sentence, translator: translator) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .success(let translation):
                self.setStripState(.loaded(
                    word: found.word,
                    translation: translation.translation,
                    sentenceTranslation: translation.sentenceTranslation,
                    translatedWord: translation.translatedWord
                ))
                self.delegate?.litraKit(self, didTranslate: found.word, in: found.sentence, translation: translation)
            case .failure(let error):
                self.setStripState(.error(word: found.word, message: error.localizedDescription))
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
