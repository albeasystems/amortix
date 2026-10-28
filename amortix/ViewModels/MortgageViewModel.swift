import Combine
import SwiftUI

final class MortgageViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var capitalText:          String        = "100000"
    @Published var yearsText:            String        = "25"
    @Published var tinText:              String        = "3.50"
    @Published var euriborText:          String        = "3.75"
    @Published var spreadText:           String        = "0.75"
    @Published var fixedPeriodYearsText: String        = "5"
    @Published var mortgageType:         MortgageType  = .fixed
    @Published var system:               AmortizationSystem = .french
    @Published var country:              CountryMarket = .spain

    var currencyCode: String { country.currencyCode }

    // MARK: - Output
    @Published private(set) var result:         MortgageResult?
    @Published var validationError: LocalizedStringKey?

    // MARK: - Calculate
    func calculate() {
        validationError = nil

        guard let capital = Double(capitalText.replacingOccurrences(of: ",", with: ".")),
              capital > 0 else {
            validationError = "error_invalid_capital"
            HapticService.error()
            return
        }

        guard let years = Int(yearsText), years > 0 else {
            validationError = "error_invalid_years"
            HapticService.error()
            return
        }

        guard let tin = Double(tinText.replacingOccurrences(of: ",", with: ".")),
              tin > 0 else {
            validationError = "error_invalid_rate"
            HapticService.error()
            return
        }

        var input = MortgageInput(
            capital:      capital,
            years:        years,
            tin:          tin,
            mortgageType: mortgageType,
            system:       system
        )

        if mortgageType == .variable || mortgageType == .mixed {
            let euribor = Double(euriborText.replacingOccurrences(of: ",", with: ".")) ?? 0
            let spread  = Double(spreadText.replacingOccurrences(of: ",", with: "."))  ?? 0
            input.euribor = euribor
            input.spread  = spread
        }

        if mortgageType == .mixed {
            input.fixedPeriodYears = Int(fixedPeriodYearsText) ?? 5
        }

        result = FinancialCalculator.mortgageResult(input: input)
        HapticService.impact(.light)
        ReviewManager.shared.registerKeyAction()   // rating first…
        AdsManager.shared.registerKeyAction()      // …then maybe an ad
    }

    func reset() {
        result         = nil
        validationError = nil
    }

    /// Clears only the result (used when inputs change after a calculation).
    func clearResult() {
        result = nil
    }

    // MARK: - Helpers
    var hasResult: Bool { result != nil }

    var showEuriborFields: Bool {
        mortgageType == .variable || mortgageType == .mixed
    }

    var showFixedPeriodField: Bool {
        mortgageType == .mixed
    }
}
