//
//  LitraKitDelegate.swift
//  LitraKit
//

import Foundation

/// Receives lookup events. Every method is optional.
///
/// Translations arrive here instead of being returned from a method because a lookup is
/// asynchronous and may be cancelled: when the user picks a new word, the previous result
/// is dropped and never delivered.
@MainActor
public protocol LitraKitDelegate: AnyObject {
    /// The user long-pressed a word; a translation request has started.
    func litraKit(_ view: LitraKitView, didSelect word: String, in sentence: String)

    /// The translator returned a result for the currently selected word.
    func litraKit(_ view: LitraKitView, didTranslate word: String, in sentence: String, translation: String)

    /// The translator threw for the currently selected word.
    func litraKit(_ view: LitraKitView, didFailToTranslate word: String, error: Error)
}

public extension LitraKitDelegate {
    func litraKit(_ view: LitraKitView, didSelect word: String, in sentence: String) {}
    func litraKit(_ view: LitraKitView, didTranslate word: String, in sentence: String, translation: String) {}
    func litraKit(_ view: LitraKitView, didFailToTranslate word: String, error: Error) {}
}
