import Combine
import SwiftUI

final class EuriborViewModel: ObservableObject {

    // MARK: - Country / currency
    @Published var country:               CountryMarket = .spain
    var currencyCode: String { country.currencyCode }

    // MARK: - Euribor review inputs
    @Published var remainingCapitalText:     String = "100000"
    @Published var remainingYearsText:       String = "25"
    @Published var remainingExtraMonthsText: String = "0"
    @Published var spreadText:               String = "0.75"

    var remainingMonths: Int {
        let y = Int(remainingYearsText)       ?? 0
        let m = Int(remainingExtraMonthsText) ?? 0
        return max(1, y * 12 + m)
    }
    @Published var currentEuriborText:    String = "3.75"
    @Published var scenarioDeltaText:     String = "1.00"

    // MARK: - Invest vs Amortize inputs (Premium)
    @Published var investAmountText:         String = ""
    @Published var investMortgageTinText:    String = ""
    @Published var investExpectedReturnText: String = ""
    @Published var investHorizonYearsText:   String = "10"

    // MARK: - Outputs
    @Published private(set) var euriborResult:  EuriborReviewResult?
    @Published private(set) var investResult:   InvestVsAmortizeResult?
    @Published var validationError: LocalizedStringKey?

    // MARK: - Euribor review
    func calculateEuribor() {
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

        guard let euribor = Double(currentEuriborText.replacingOccurrences(of: ",", with: ".")),
              euribor > 0 else {
            validationError = "error_invalid_rate"
            HapticService.error()
            return
        }

        let spread = Double(spreadText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let delta  = Double(scenarioDeltaText.replacingOccurrences(of: ",", with: ".")) ?? 0

        let input = EuriborReviewInput(
            remainingCapital: capital,
            remainingMonths:  remainingMonths,
            spread:           spread,
            currentEuribor:   euribor,
            scenarioDelta:    delta
        )

        euriborResult = FinancialCalculator.euriborReviewResult(input: input)
        HapticService.impact(.light)
        ReviewManager.shared.registerKeyAction()   // rating first…
        AdsManager.shared.registerKeyAction()      // …then maybe an ad
    }

    // MARK: - Invest vs Amortize (Premium)
    func compareInvestVsAmortize() {
        validationError = nil

        guard let amount = Double(investAmountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            validationError = "error_invalid_amount"
            HapticService.error()
            return
        }

        guard let tin = Double(investMortgageTinText.replacingOccurrences(of: ",", with: ".")),
              tin > 0 else {
            validationError = "error_invalid_rate"
            HapticService.error()
            return
        }

        let expectedReturn = Double(investExpectedReturnText.replacingOccurrences(of: ",", with: ".")) ?? 7
        let horizonYears   = Int(investHorizonYearsText) ?? 10

        let input = InvestVsAmortizeInput(
            amount:         amount,
            mortgageTin:    tin,
            expectedReturn: expectedReturn,
            horizonYears:   horizonYears
        )

        investResult = FinancialCalculator.investVsAmortizeResult(input: input)
        HapticService.impact(.light)
        ReviewManager.shared.registerKeyAction()   // rating first…
        AdsManager.shared.registerKeyAction()      // …then maybe an ad
    }

    func resetEuribor() {
        euriborResult  = nil
        validationError = nil
    }

    func resetInvest() {
        investResult   = nil
        validationError = nil
    }

    // MARK: - Helpers
    var hasEuriborResult: Bool { euriborResult != nil }
    var hasInvestResult:  Bool { investResult  != nil }

    var scenarioDeltaFormatted: String {
        let delta = Double(scenarioDeltaText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return delta >= 0 ? "+\(scenarioDeltaText)%" : "\(scenarioDeltaText)%"
    }
}
