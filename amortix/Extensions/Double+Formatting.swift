import Foundation

extension Double {

    var asCurrency: String {
        formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }

    /// Currency formatted with an explicit ISO 4217 code (e.g. "USD", "INR", "BRL")
    func asCurrency(_ code: String) -> String {
        formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    func asCompactCurrency(_ code: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        nf.maximumFractionDigits = 0
        let symbol = nf.currencySymbol ?? code
        if self >= 1_000_000 { return String(format: "%.1fM \(symbol)", self / 1_000_000) }
        if self >= 1_000     { return String(format: "%.0fk \(symbol)", self / 1_000) }
        return String(format: "%.0f \(symbol)", self)
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
        currencyDifference(code: "EUR", prefix: prefix)
    }

    func currencyDifference(code: String, prefix: Bool = true) -> String {
        let formatted = abs(self).asCurrency(code)
        if prefix {
            return self >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return formatted
    }
}
