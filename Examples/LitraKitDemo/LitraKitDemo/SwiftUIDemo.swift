import SwiftUI
import LitraKit

/// The same feature from SwiftUI through the nested wrapper.
struct SwiftUIDemo: View {
    @State private var translator = MockTranslator()
    @State private var lastLookup = "—"

    var body: some View {
        VStack(spacing: 0) {
            LitraKitView.Representable(
                text: sampleText,
                font: .systemFont(ofSize: 19),
                translator: translator,
                configuration: configuration
            ) { word, _, translation in
                lastLookup = "\(word) → \(translation)"
            }
            Text("Последнее: \(lastLookup)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.secondarySystemBackground))
        }
    }

    private var configuration: LitraKitConfiguration {
        var config = LitraKitConfiguration()
        config.underlineColor = .systemOrange
        config.loupeMagnification = 1.8
        return config
    }
}
