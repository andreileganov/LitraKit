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
    /// - Returns: The text to show in the translation bar.
    func translate(word: String, in sentence: String) async throws -> String
}
