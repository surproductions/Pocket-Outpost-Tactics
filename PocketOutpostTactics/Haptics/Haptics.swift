import UIKit

enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func impact(heavy: Bool = false) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: heavy ? .heavy : .medium).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// One place to fire matching sound + haptic feedback.
enum Feedback {
    static func select() { SoundEngine.shared.play(.select); Haptics.tap() }
    static func tap() { SoundEngine.shared.play(.tap); Haptics.tap() }
    static func error() { SoundEngine.shared.play(.error); Haptics.warning() }
}
