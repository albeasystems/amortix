import Foundation

struct MortgageInput {
    var capital: Double        = 200_000
    var years: Int             = 30
    var tin: Double            = 3.5
    var mortgageType: MortgageType = .fixed
    var euribor: Double        = 3.0
    var spread: Double         = 1.0
    var fixedPeriodYears: Int  = 5

    var effectiveRate: Double {
        switch mortgageType {
        case .fixed:    return tin
        case .variable: return euribor + spread
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
}

struct AmortizationRow: Identifiable {
    let id:        Int
    let payment:   Double
    let principal: Double
    let interest:  Double
    let balance:   Double
}
