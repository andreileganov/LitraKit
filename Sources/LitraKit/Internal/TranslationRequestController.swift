//
//  TranslationRequestController.swift
//  LitraKit
//

import Foundation

/// Runs one translation at a time. Starting a new request cancels the previous one, and a
/// result that arrives for a superseded request is dropped even if the translator ignored
/// cancellation.
@MainActor
final class TranslationRequestController {
    enum Outcome {
        case success(LitraTranslation)
        case failure(Error)
    }

    private var task: Task<Void, Never>?
    private var generation = 0

    var isRunning: Bool { task != nil }

    func request(
        word: String,
        sentence: String,
        translator: LitraTranslating,
        completion: @escaping @MainActor (Outcome) -> Void
    ) {
        cancel()
        generation += 1
        let current = generation

        task = Task { [weak self] in
            let outcome: Outcome
            do {
                outcome = .success(try await translator.translate(word: word, in: sentence))
            } catch {
                outcome = .failure(error)
            }
            guard let self, !Task.isCancelled, self.generation == current else { return }
            self.task = nil
            completion(outcome)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        generation += 1
    }
}
