import Combine
import SwiftUI

final class PartialAmortizationViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var remainingCapitalText:        String         = "100000"
    @Published var remainingYearsText:          String         = "20"    // years component
    @Published var remainingExtraMonthsText:    String         = "0"     // 0–11 extra months
    @Published var currentRateText:             String         = "3.50"
    @Published var amountToAmortizeText:        String         = ""
    @Published var commissionMode:              CommissionMode = .none {
        didSet { if oldValue != commissionMode { result = nil } }
    }
    @Published var mortgageType:                MortgageType   = .variable
    @Published var yearsSinceSigningText:       String         = "5"
    @Published var customCommissionPercentText: String         = ""
    @Published var customCommissionFixedText:   String         = ""
    @Published var country:                     CountryMarket  = .spain

    var currencyCode: String { country.currencyCode }

    /// Total remaining months computed from years + extra months fields.
    var remainingMonths: Int {
        let y = Int(remainingYearsText)  ?? 0
        let m = Int(remainingExtraMonthsText) ?? 0
        return max(1, y * 12 + m)
    }

    // MARK: - Output
    @Published private(set) var result:    PartialAmortizationResult?
    @Published var validationError: LocalizedStringKey?

    // MARK: - Simulate
    func simulate() {
        validationError = nil

        guard let capital = Double(remainingCapitalText.replacingOccurrences(of: ",", with: ".")),
              capital > 0 else {
            validationError = "error_invalid_capital"
            HapticService.error()
            return
        }

        guard remainingMonths > 0 else {
            validationError = "error_invalid_years"
            HapticService.error()
            return
        }

        guard let rate = Double(currentRateText.replacingOccurrences(of: ",", with: ".")),
              rate > 0 else {
            validationError = "error_invalid_rate"
            HapticService.error()
            return
        }

        guard let amount = Double(amountToAmortizeText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            validationError = "error_invalid_amount"
            HapticService.error()
            return
        }

        guard amount < capital else {
            validationError = "error_amount_exceeds_capital"
            HapticService.error()
            return
        }

        let input = PartialAmortizationInput(
            remainingCapital:        capital,
            remainingMonths:         remainingMonths,
            currentRate:             rate,
            amountToAmortize:        amount,
            commissionMode:          commissionMode,
            mortgageType:            mortgageType,
            yearsSinceSigning:       Int(yearsSinceSigningText) ?? 0,
            customCommissionPercent: Double(customCommissionPercentText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            customCommissionFixed:   Double(customCommissionFixedText.replacingOccurrences(of: ",", with: "."))   ?? 0,
            country:                 country
        )

        result = FinancialCalculator.partialAmortizationResult(input: input)
        HapticService.impact(.light)
        ReviewManager.shared.registerKeyAction()   // rating first…
        AdsManager.shared.registerKeyAction()      // …then maybe an ad
    }

    func reset() {
        result         = nil
        validationError = nil
    }

    // MARK: - Helpers
    var hasResult: Bool { result != nil }

    var showCustomCommission: Bool {
        commissionMode == .percent || commissionMode == .fixed
    }

    var showYearsSinceSigning: Bool {
        commissionMode == .auto
    }

    var commissionInfoKey: LocalizedStringKey {
        mortgageType == .variable ? "partial_info_law_variable" : "partial_info_law_fixed"
    }

    /// Human-readable term string: "X años Y meses" (used in narrative).
    static func termLabel(months: Int) -> String {
        let y = months / 12
        let m = months % 12
        if y > 0 && m > 0 { return "\(y) a \(m) m" }
        if y > 0 { return "\(y) a" }
        return "\(m) m"
    }
}
