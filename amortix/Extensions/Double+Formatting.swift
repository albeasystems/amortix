import Foundation

extension Double {

    var asCurrency: String {
        formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }

    var asPercentage: String {
        String(format: "%.2f%%", self)
    }

    var asCompactCurrency: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM €", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.0fk €", self / 1_000)
        } else {
            return String(format: "%.0f €", self)
        }
    }

    var roundedToTwoDecimals: Double {
        (self * 100).rounded() / 100
    }

    func currencyDifference(prefix: Bool = true) -> String {
        let formatted = abs(self).asCurrency
        if prefix {
            return self >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return formatted
    }
}
