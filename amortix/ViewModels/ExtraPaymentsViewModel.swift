import Combine
import SwiftUI

final class ExtraPaymentsViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var remainingCapitalText:     String = "100000"
    @Published var remainingYearsText:       String = "25"
    @Published var remainingExtraMonthsText: String = "0"
    @Published var currentRateText:          String = "3.50"
    @Published var extraMonthlyText:         String = ""
    @Published var country:                  CountryMarket = .spain

    var remainingMonths: Int {
        let y = Int(remainingYearsText)       ?? 0
        let m = Int(remainingExtraMonthsText) ?? 0
        return max(1, y * 12 + m)
    }

    // MARK: - Output
    @Published private(set) var result: ExtraPaymentsResult?
    @Published var validationError:     LocalizedStringKey?

    var currencyCode: String { country.currencyCode }

    // MARK: - Simulate
    func simulate() {
        validationError = nil

        guard let capital = Double(remainingCapitalText.replacingOccurrences(of: ",", with: ".")),
              capital > 0 else {
            validationError = "error_invalid_capital"; HapticService.error(); return
        }
        guard remainingMonths > 0 else {
            validationError = "error_invalid_years"; HapticService.error(); return
        }
        guard let rate = Double(currentRateText.replacingOccurrences(of: ",", with: ".")),
              rate > 0 else {
            validationError = "error_invalid_rate"; HapticService.error(); return
        }
        guard let extra = Double(extraMonthlyText.replacingOccurrences(of: ",", with: ".")),
              extra > 0 else {
            validationError = "error_invalid_amount"; HapticService.error(); return
        }

        let input = ExtraPaymentsInput(
            remainingCapital: capital,
            remainingMonths:  remainingMonths,
            currentRate:      rate,
            extraMonthly:     extra
        )
        result = FinancialCalculator.extraPaymentsResult(input: input)
        HapticService.impact(.light)
        ReviewManager.shared.registerKeyAction()   // rating first…
        AdsManager.shared.registerKeyAction()      // …then maybe an ad
    }

    func reset() { result = nil; validationError = nil }
    var hasResult: Bool { result != nil }
}
