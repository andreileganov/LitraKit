import SwiftUI
import LitraKit

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                UIKitDemo()
                    .ignoresSafeArea(edges: .bottom)
                    .tabItem { Label("UIKit", systemImage: "square.stack.3d.up") }

                SwiftUIDemo()
                    .tabItem { Label("SwiftUI", systemImage: "swift") }
            }
        }
    }
}

/// Fake translator: a tiny dictionary with a delay, so loading and cancellation are visible.
/// Translates "bank" by context to show why LitraKit passes the sentence along.
final class MockTranslator: LitraTranslating {
    struct Unavailable: LocalizedError {
        var errorDescription: String? { "Перевод недоступен" }
    }

    private let dictionary: [String: String] = [
        "river": "река", "was": "был", "quiet": "тихий", "she": "она", "opened": "открыла",
        "account": "счёт", "at": "в", "the": "—", "reader": "читатель", "word": "слово",
        "hold": "удерживать", "finger": "палец", "translation": "перевод", "appears": "появляется",
        "top": "верх", "loupe": "лупа", "magnifies": "увеличивает", "text": "текст",
        "under": "под", "your": "ваш", "context": "контекст", "matters": "имеет значение",
    ]

    /// Sentence translations with how each word appears inside them.
    private let sentences: [String: (translation: String, words: [String: String])] = [
        "The river bank was quiet.": (
            "Берег реки был тихим.",
            ["river": "реки", "bank": "Берег", "was": "был", "quiet": "тихим"]
        ),
        "She opened an account at the bank.": (
            "Она открыла счёт в банке.",
            ["she": "Она", "opened": "открыла", "account": "счёт", "bank": "банке"]
        ),
        "Context matters.": ("Контекст имеет значение.", ["context": "Контекст", "matters": "имеет значение"]),
    ]

    func translate(word: String, in sentence: String) async throws -> LitraTranslation {
        try await Task.sleep(nanoseconds: 600_000_000)
        let key = word.lowercased()
        if key == "unknown" { throw Unavailable() }

        let wordTranslation: String
        if key == "bank" {
            wordTranslation = sentence.lowercased().contains("river") ? "берег" : "банк"
        } else {
            wordTranslation = dictionary[key] ?? "«\(word)»"
        }

        guard let known = sentences[sentence] else {
            return LitraTranslation(translation: wordTranslation)
        }
        return LitraTranslation(
            translation: wordTranslation,
            sentenceTranslation: known.translation,
            translatedWord: known.words[key]
        )
    }
}

let sampleText = """
Context matters. The river bank was quiet. She opened an account at the bank.

Hold your finger on any word: the loupe magnifies the text under your finger, \
and when you let go the translation appears at the top. Try a word that is unknown \
to see an error.

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit \
voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab \
illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia \
consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. The reader keeps \
reading; every word is one long press away.
"""
