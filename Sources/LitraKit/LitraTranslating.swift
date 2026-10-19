//
//  LitraTranslating.swift
//  LitraKit
//

import Foundation

/// Your translator. LitraKit never talks to a network or a translation provider itself —
/// it hands you the word and its sentence and shows whatever you return.
///
/// The call runs inside a `Task` that LitraKit cancels when the user picks another word,
/// so check `Task.isCancelled` (or use cancellable APIs like `URLSession.data(for:)`)
/// if your work is expensive.
public protocol LitraTranslating: AnyObject {
    /// - Parameters:
    ///   - word: The word under the user's finger, without surrounding punctuation.
    ///   - sentence: The sentence that contains the word, for context-aware translation.
    func translate(word: String, in sentence: String) async throws -> LitraTranslation
}

/// What the translation strip shows.
///
/// With `sentenceTranslation` and `translatedWord` the strip shows the whole translated
/// sentence with the word centered and underlined; otherwise just `translation`.
public struct LitraTranslation: Equatable {
    /// Translation of the word itself, e.g. "взволновать".
    public var translation: String
    /// The whole sentence translated, e.g. "Его голос взволновал их."
    public var sentenceTranslation: String?
    /// How the word appears inside `sentenceTranslation`, e.g. "взволновал".
    public var translatedWord: String?

    public init(translation: String, sentenceTranslation: String? = nil, translatedWord: String? = nil) {
        self.translation = translation
        self.sentenceTranslation = sentenceTranslation
        self.translatedWord = translatedWord
    }
}
