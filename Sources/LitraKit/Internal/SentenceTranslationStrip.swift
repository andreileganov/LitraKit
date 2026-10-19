import SwiftUI
import UIKit

// Ported from Litra (Litra/Views/Reader/SentenceTranslationStrip.swift).
// Changes vs. the original: `PopupState` → `StripState`, `LitraColors.accent` →
// `accent` passed in from `LitraKitConfiguration.underlineColor`; the highlighted word
// uses SwiftUI attributes so the underline shows and `.label` so it reads in dark mode.

/// What the strip shows. Mirrors Litra's `PopupState`.
enum StripState: Equatable {
    case loading(word: String)
    case loaded(word: String, translation: String,
                sentenceTranslation: String?, translatedWord: String?)
    case error(word: String, message: String)
}

/// Top-of-screen translation strip shown when Level 1 long-press fires.
///
/// Layout goal:
/// - Full translated sentence on a single line.
/// - The translated word (e.g. "взволновал" for "thrilled") is pinned to
///   horizontal center of the screen, rendered black with a green underline.
/// - Surrounding sentence text is gray (secondary label).
/// - Edges fade to transparent over `fadeInset` pt (sentence is usually wider
///   than screen and overflows past the fade).
/// - Appears with fade-in (parent applies `.transition(.opacity)`).
///
/// Fallback (no sentence translation or word not found in sentence):
/// show only the translated word, centered, black with green underline.
///
/// Implementation notes:
/// - Uses `AttributedString` so black + green underline are UIKit attributes
///   inside a single `Text`. SwiftUI modifiers cannot override them.
/// - Centering is done with `.offset(x:)` computed from measured widths via
///   `NSString.size(withAttributes:)` — deterministic on every render, no
///   dependence on `.onAppear` / `.onChange` timing.
struct SentenceTranslationStrip: View {
    let state: StripState?
    let accent: Color

    private let uiFont: UIFont = .systemFont(ofSize: 15, weight: .medium)
    private let rowHeight: CGFloat = 30
    private let fadeInset: CGFloat = 44

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity)

            case .loaded(let word, let translation, let sentenceTranslation, let translatedWord):
                if let sentence = sentenceTranslation,
                   !sentence.isEmpty,
                   let highlight = translatedWord,
                   !highlight.isEmpty,
                   let range = sentence.range(of: highlight, options: .caseInsensitive) {
                    sentenceRow(sentence: sentence, range: range)
                } else {
                    let display = translation.isEmpty ? word : translation
                    Text(styledAttributedString(display, highlighted: true))
                        .frame(maxWidth: .infinity)
                }

            default:
                EmptyView()
            }
        }
        .frame(height: rowHeight)
        .padding(.top, 4)
    }

    // MARK: - Sentence with centered highlighted word

    private func sentenceRow(sentence: String, range: Range<String.Index>) -> some View {
        let before = String(sentence[sentence.startIndex..<range.lowerBound])
        let matched = String(sentence[range])
        let after = String(sentence[range.upperBound..<sentence.endIndex])

        var attr = AttributedString()
        attr.append(styledAttributedString(before, highlighted: false))
        attr.append(styledAttributedString(matched, highlighted: true))
        attr.append(styledAttributedString(after, highlighted: false))

        // Horizontal center of the matched word, measured from the start of the sentence.
        let matchedCenter = width(of: before) + width(of: matched) / 2

        return GeometryReader { geo in
            Text(attr)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: geo.size.width / 2 - matchedCenter)
        }
        .mask(edgeFadeMask)
    }

    // MARK: - AttributedString

    /// SwiftUI-scope attributes: `Text` ignores UIKit underline keys, and `.label` instead
    /// of black keeps the word readable in dark mode.
    private func styledAttributedString(_ text: String, highlighted: Bool) -> AttributedString {
        var string = AttributedString(text)
        string.swiftUI.font = Font(uiFont as CTFont)
        if highlighted {
            string.swiftUI.foregroundColor = Color(.label)
            string.swiftUI.underlineStyle = Text.LineStyle(pattern: .solid, color: accent)
        } else {
            string.swiftUI.foregroundColor = Color(.secondaryLabel)
        }
        return string
    }

    // MARK: - Fade mask

    private var edgeFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: fadeInset)
            Color.black
            LinearGradient(colors: [.black, .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: fadeInset)
        }
    }

    private func width(of string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: uiFont]).width
    }
}

// MARK: - Host

/// Observable state for the strip, owned by `LitraKitView`.
final class StripModel: ObservableObject {
    @Published var state: StripState?
    @Published var accent: Color = .accentColor
}

/// Shows the strip only while there is a state, with the same transition and animation
/// Litra's `ReaderView` applies around it.
struct SentenceTranslationStripHost: View {
    @ObservedObject var model: StripModel

    var body: some View {
        VStack(spacing: 0) {
            if model.state != nil {
                SentenceTranslationStrip(state: model.state, accent: model.accent)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.state)
    }
}
