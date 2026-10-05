import Foundation

enum MortgageType: String, CaseIterable, Identifiable, Codable {
    case fixed
    case variable
    case mixed

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .fixed:    return "calculator_type_fixed"
        case .variable: return "calculator_type_variable"
        case .mixed:    return "calculator_type_mixed"
        }
    }
}

enum CommissionMode: String, CaseIterable, Identifiable {
    case auto
    case percent
    case fixed
    case none

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .auto:    return "partial_commission_mode_auto"
        case .percent: return "partial_commission_mode_percent"
        case .fixed:   return "partial_commission_mode_fixed"
        case .none:    return "partial_commission_mode_none"
        }
    }

    // MARK: - Ley 5/2019 (Spain) commission logic
    static func calculate(
        mode: CommissionMode,
        mortgageType: MortgageType,
        yearsSinceSigning: Int,
        amount: Double,
        customPercent: Double = 0,
        customFixed: Double = 0
    ) -> Double {
        switch mode {
        case .auto:
            return autoCommission(
                mortgageType: mortgageType,
                yearsSinceSigning: yearsSinceSigning,
                amount: amount
            )
        case .percent:
            return amount * customPercent / 100
        case .fixed:
            return customFixed
        case .none:
            return 0
        }
    }

    private static func autoCommission(
        mortgageType: MortgageType,
        yearsSinceSigning: Int,
        amount: Double
    ) -> Double {
        switch mortgageType {
        case .variable:
            // 0.25% first 3 years · 0% from year 4 onwards
            return yearsSinceSigning < 3 ? amount * 0.0025 : 0
        case .fixed, .mixed:
            // 2% first 10 years · 1.5% from year 11 onwards
            return yearsSinceSigning < 10 ? amount * 0.02 : amount * 0.015
        }
    }
}
