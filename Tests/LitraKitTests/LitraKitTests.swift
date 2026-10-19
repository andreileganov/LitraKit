import XCTest
@testable import LitraKit

final class WordLocatorTests: XCTestCase {
    private let text = "The river bank was quiet. She opened an account at the bank, didn't she?"

    private func index(of substring: String, offset: Int = 0) -> Int {
        (text as NSString).range(of: substring).location + offset
    }

    func testFindsWordAtStartMiddleAndEnd() {
        XCTAssertEqual(WordLocator.word(at: index(of: "river"), in: text)?.word, "river")
        XCTAssertEqual(WordLocator.word(at: index(of: "river", offset: 2), in: text)?.word, "river")
        XCTAssertEqual(WordLocator.word(at: index(of: "river", offset: 4), in: text)?.word, "river")
    }

    func testReturnsSentenceContainingTheWord() {
        let first = WordLocator.word(at: index(of: "bank"), in: text)
        XCTAssertEqual(first?.sentence, "The river bank was quiet.")

        let second = WordLocator.word(at: index(of: "account"), in: text)
        XCTAssertEqual(second?.sentence, "She opened an account at the bank, didn't she?")
    }

    func testWordRangeMatchesWord() {
        let found = WordLocator.word(at: index(of: "quiet"), in: text)
        XCTAssertEqual(found?.wordRange, NSRange(location: index(of: "quiet"), length: 5))
    }

    func testStripsPunctuationAndKeepsApostrophes() {
        XCTAssertEqual(WordLocator.word(at: index(of: "bank,"), in: text)?.word, "bank")
        XCTAssertEqual(WordLocator.word(at: index(of: "didn't", offset: 4), in: text)?.word, "didn't")
    }

    func testReturnsNilBetweenWords() {
        XCTAssertNil(WordLocator.word(at: index(of: " river"), in: text))
        XCTAssertNil(WordLocator.word(at: index(of: "."), in: text))
    }

    func testReturnsNilOutOfBounds() {
        XCTAssertNil(WordLocator.word(at: -1, in: text))
        XCTAssertNil(WordLocator.word(at: (text as NSString).length, in: text))
        XCTAssertNil(WordLocator.word(at: 0, in: ""))
    }

    func testHandlesNonLatinAndEmoji() {
        let mixed = "Привет 👋 мир. Grüße aus Köln."
        let ns = mixed as NSString
        XCTAssertEqual(WordLocator.word(at: ns.range(of: "мир").location + 1, in: mixed)?.word, "мир")
        XCTAssertEqual(WordLocator.word(at: ns.range(of: "Köln").location + 2, in: mixed)?.word, "Köln")
        XCTAssertEqual(WordLocator.word(at: ns.range(of: "Köln").location, in: mixed)?.sentence, "Grüße aus Köln.")
    }

    func testSentenceStaysInsideParagraph() {
        let paragraphs = "First paragraph without a period\nSecond one here."
        let ns = paragraphs as NSString
        let found = WordLocator.word(at: ns.range(of: "Second").location, in: paragraphs)
        XCTAssertEqual(found?.sentence, "Second one here.")
    }
}

/// Translator that waits until the test releases each word.
private final class ControlledTranslator: LitraTranslating {
    var continuations: [String: CheckedContinuation<String, Error>] = [:]
    var requested: [String] = []

    func translate(word: String, in sentence: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.requested.append(word)
                self.continuations[word] = continuation
            }
        }
    }

    @MainActor
    func finish(_ word: String, with result: Result<String, Error>) {
        continuations.removeValue(forKey: word)?.resume(with: result)
    }
}

private struct TestError: Error {}

@MainActor
final class TranslationRequestControllerTests: XCTestCase {
    private func waitUntil(_ condition: @escaping () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), "condition not met in time", file: file, line: line)
    }

    func testDeliversResult() async {
        let controller = TranslationRequestController()
        let translator = ControlledTranslator()
        var results: [String] = []

        controller.request(word: "bank", sentence: "s", translator: translator) { outcome in
            if case .success(let text) = outcome { results.append(text) }
        }
        await waitUntil { translator.requested == ["bank"] }
        translator.finish("bank", with: .success("берег"))
        await waitUntil { results == ["берег"] }
        XCTAssertFalse(controller.isRunning)
    }

    func testNewRequestDropsPreviousResult() async {
        let controller = TranslationRequestController()
        let translator = ControlledTranslator()
        var results: [String] = []
        let collect: @MainActor (TranslationRequestController.Outcome) -> Void = { outcome in
            if case .success(let text) = outcome { results.append(text) }
        }

        controller.request(word: "river", sentence: "s", translator: translator, completion: collect)
        await waitUntil { translator.requested == ["river"] }
        controller.request(word: "bank", sentence: "s", translator: translator, completion: collect)
        await waitUntil { translator.requested == ["river", "bank"] }

        // The first translator ignores cancellation and still returns — it must be dropped.
        translator.finish("river", with: .success("река"))
        translator.finish("bank", with: .success("берег"))
        await waitUntil { results == ["берег"] }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(results, ["берег"])
    }

    func testCancelDropsResult() async {
        let controller = TranslationRequestController()
        let translator = ControlledTranslator()
        var delivered = false

        controller.request(word: "bank", sentence: "s", translator: translator) { _ in delivered = true }
        await waitUntil { translator.requested == ["bank"] }
        controller.cancel()
        translator.finish("bank", with: .success("берег"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(delivered)
    }

    func testDeliversError() async {
        let controller = TranslationRequestController()
        let translator = ControlledTranslator()
        var failed = false

        controller.request(word: "bank", sentence: "s", translator: translator) { outcome in
            if case .failure(let error) = outcome, error is TestError { failed = true }
        }
        await waitUntil { translator.requested == ["bank"] }
        translator.finish("bank", with: .failure(TestError()))
        await waitUntil { failed }
    }
}
