import UIKit

enum HapticService {

    static func premiumToggle() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    static func selection() {
        let g = UISelectionFeedbackGenerator()
        g.selectionChanged()
    }

    static func error() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
    }
}
