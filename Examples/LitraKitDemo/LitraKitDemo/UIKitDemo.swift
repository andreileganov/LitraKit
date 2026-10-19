import SwiftUI
import UIKit
import LitraKit

/// The primary integration: an existing UITextView wrapped by LitraKitView.
final class ReaderViewController: UIViewController, LitraKitDelegate {
    private let translator = MockTranslator()
    private let logLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Your text view, styled your way — LitraKit doesn't touch it.
        let textView = UITextView()
        textView.isEditable = false
        textView.text = sampleText
        textView.font = UIFont(name: "Georgia", size: 20)
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 80, left: 20, bottom: 60, right: 20)

        let litra = LitraKitView(textView: textView)
        litra.translator = translator
        litra.delegate = self
        litra.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(litra)

        logLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logLabel.textColor = .secondaryLabel
        logLabel.numberOfLines = 2
        logLabel.backgroundColor = .secondarySystemBackground
        logLabel.text = " delegate: —"
        logLabel.accessibilityIdentifier = "delegateLog"
        logLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logLabel)

        NSLayoutConstraint.activate([
            litra.topAnchor.constraint(equalTo: view.topAnchor),
            litra.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            litra.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            litra.bottomAnchor.constraint(equalTo: logLabel.topAnchor),
            logLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            logLabel.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func litraKit(_ view: LitraKitView, didSelect word: String, in sentence: String) {
        log("didSelect \(word) | \(sentence)")
    }

    func litraKit(_ view: LitraKitView, didTranslate word: String, in sentence: String, translation: String) {
        log("didTranslate \(word) → \(translation)")
    }

    func litraKit(_ view: LitraKitView, didFailToTranslate word: String, error: Error) {
        log("didFail \(word): \(error.localizedDescription)")
    }

    private func log(_ message: String) {
        print("[LitraKitDemo] \(message)")
        logLabel.text = " " + message
    }
}

struct UIKitDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ReaderViewController { ReaderViewController() }
    func updateUIViewController(_ controller: ReaderViewController, context: Context) {}
}
