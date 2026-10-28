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

/// Amortization repayment system — governs how each instalment splits between
/// principal and interest. Orthogonal to `MortgageType` (which only sets the
/// rate). Mirrors Capital's model; applied to the main calculator for
/// fixed/variable mortgages (mixed keeps its two-phase French behaviour).
enum AmortizationSystem: String, CaseIterable, Identifiable, Codable {
    case french      // constant payment
    case linear      // constant principal (a.k.a. German); payment decreases
    case american    // interest-only, full principal as a final bullet

    var id: String { rawValue }

    var localizedKey: String { "system_\(rawValue)" }
    var infoKey:      String { "systems_info_\(rawValue)" }
}

enum CommissionMode: String, CaseIterable, Identifiable {
    case none
    case fixed
    case percent
    case auto

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .auto:    return "partial_commission_mode_auto"
        case .percent: return "partial_commission_mode_percent"
        case .fixed:   return "partial_commission_mode_fixed"
        case .none:    return "partial_commission_mode_none"
        }
    }

    // MARK: - Multi-country commission calculation
    // Auto mode delegates to CountryMarket law; other modes are manual overrides.
    static func calculate(
        mode: CommissionMode,
        mortgageType: MortgageType,
        yearsSinceSigning: Int,
        amount: Double,
        customPercent: Double = 0,
        customFixed: Double = 0,
        country: CountryMarket = .spain,
        monthlyRate: Double = 0,
        remainingMonths: Int = 0
    ) -> Double {
        switch mode {
        case .auto:
            return country.earlyRepaymentCommission(
                amount: amount,
                mortgageType: mortgageType,
                yearsSinceSigning: yearsSinceSigning,
                monthlyRate: monthlyRate,
                remainingMonths: remainingMonths
            )
        case .percent:
            return amount * customPercent / 100
        case .fixed:
            return customFixed
        case .none:
            return 0
        }
    }
}
