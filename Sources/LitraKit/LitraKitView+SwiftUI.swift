//
//  LitraKitView+SwiftUI.swift
//  LitraKit
//

import SwiftUI
import UIKit

extension LitraKitView {
    /// SwiftUI wrapper. Creates a read-only `UITextView` for `text` and wraps it.
    ///
    /// ```swift
    /// LitraKitView.Representable(text: chapter, translator: translator) { word, sentence, translation in
    ///     saveCard(word, translation.translation)
    /// }
    /// ```
    public struct Representable: UIViewRepresentable {
        public var text: String
        public var font: UIFont
        public var translator: LitraTranslating?
        public var configuration: LitraKitConfiguration
        public var onTranslate: ((_ word: String, _ sentence: String, _ translation: LitraTranslation) -> Void)?

        public init(
            text: String,
            font: UIFont = .preferredFont(forTextStyle: .body),
            translator: LitraTranslating?,
            configuration: LitraKitConfiguration = LitraKitConfiguration(),
            onTranslate: ((_ word: String, _ sentence: String, _ translation: LitraTranslation) -> Void)? = nil
        ) {
            self.text = text
            self.font = font
            self.translator = translator
            self.configuration = configuration
            self.onTranslate = onTranslate
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        public func makeUIView(context: Context) -> LitraKitView {
            let textView = UITextView()
            textView.isEditable = false
            textView.adjustsFontForContentSizeCategory = true
            textView.textColor = .label
            textView.backgroundColor = .systemBackground
            textView.textContainerInset = UIEdgeInsets(top: 72, left: 16, bottom: 24, right: 16)
            let view = LitraKitView(textView: textView, configuration: configuration)
            view.delegate = context.coordinator
            return view
        }

        public func updateUIView(_ view: LitraKitView, context: Context) {
            context.coordinator.onTranslate = onTranslate
            view.translator = translator
            view.configuration = configuration
            if view.textView.text != text || view.textView.font != font {
                view.clearSelection()
                view.textView.text = text
                view.textView.font = font
            }
        }

        @MainActor
        public final class Coordinator: LitraKitDelegate {
            var onTranslate: ((String, String, LitraTranslation) -> Void)?

            public func litraKit(_ view: LitraKitView, didTranslate word: String, in sentence: String, translation: LitraTranslation) {
                onTranslate?(word, sentence, translation)
            }
        }
    }
}
