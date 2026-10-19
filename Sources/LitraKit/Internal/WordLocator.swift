//
//  WordLocator.swift
//  LitraKit
//

import Foundation

/// A word found in a text, with the sentence around it.
struct LocatedWord: Equatable {
    let word: String
    let wordRange: NSRange
    let sentence: String
}

/// Pure text logic: character offset → word + sentence. No UIKit, fully unit-testable.
enum WordLocator {
    /// Finds the word that contains the character at `index` (UTF-16 offset).
    /// Returns `nil` when `index` points at whitespace or punctuation between words.
    static func word(at index: Int, in text: String) -> LocatedWord? {
        let nsText = text as NSString
        guard index >= 0, index < nsText.length else { return nil }

        guard let wordRange = enclosingRange(of: index, in: nsText, unit: .byWords) else { return nil }
        let sentenceRange = enclosingRange(of: index, in: nsText, unit: .bySentences)
            ?? NSRange(location: 0, length: nsText.length)

        let sentence = nsText.substring(with: sentenceRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return LocatedWord(
            word: nsText.substring(with: wordRange),
            wordRange: wordRange,
            sentence: sentence
        )
    }

    private static func enclosingRange(
        of index: Int,
        in text: NSString,
        unit: NSString.EnumerationOptions
    ) -> NSRange? {
        var found: NSRange?
        // Only scan the paragraph around the index — books can be long.
        let paragraph = text.paragraphRange(for: NSRange(location: index, length: 0))
        text.enumerateSubstrings(in: paragraph, options: [unit, .substringNotRequired]) { _, range, _, stop in
            if NSLocationInRange(index, range) {
                found = range
                stop.pointee = true
            } else if range.location > index {
                stop.pointee = true
            }
        }
        return found
    }
}
