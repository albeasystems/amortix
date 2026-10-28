import Foundation

struct MortgageInput {
    var capital: Double        = 200_000
    var years: Int             = 30
    var tin: Double            = 3.5
    var mortgageType: MortgageType = .fixed
    var system: AmortizationSystem = .french
    var euribor: Double        = 3.0
    var spread: Double         = 1.0
    var fixedPeriodYears: Int  = 5

    var effectiveRate: Double {
        switch mortgageType {
        case .fixed:    return tin
        case .variable: return FinancialCalculator.variableRate(euribor: euribor, spread: spread)
        case .mixed:    return tin
        }
    }

    var monthlyRate: Double { effectiveRate / 12 / 100 }
    var totalMonths: Int    { years * 12 }
}

struct MortgageResult {
    let monthlyPayment:    Double
    let totalInterest:     Double
    let totalCost:         Double
    let amortizationTable: [AmortizationRow]

    // Type + mixed-mortgage two-phase detail (nil for fixed/variable)
    var mortgageType:        MortgageType = .fixed

    // Amortization system + whether the headline payment stays constant
    // (true only for French). For linear/american `monthlyPayment` is the
    // first-period instalment.
    var system:              AmortizationSystem = .french
    var paymentIsConstant:   Bool         = true

    var fixedPhasePayment:   Double?      = nil
    var variablePhasePayment: Double?     = nil
    var fixedPhaseMonths:    Int?         = nil
    var balanceAfterFixed:   Double?      = nil
    var variableRate:        Double?      = nil
}

struct AmortizationRow: Identifiable {
    let id:        Int
    let payment:   Double
    let principal: Double
    let interest:  Double
    let balance:   Double
}
