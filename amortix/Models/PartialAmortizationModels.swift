import Foundation

struct PartialAmortizationInput {
    var remainingCapital:         Double = 150_000
    var remainingMonths:          Int    = 240
    var currentRate:              Double = 3.5
    var amountToAmortize:         Double = 20_000
    var commissionMode:           CommissionMode = .auto
    var mortgageType:             MortgageType   = .variable
    var yearsSinceSigning:        Int    = 5
    var customCommissionPercent:  Double = 0
    var customCommissionFixed:    Double = 0

    var commission: Double {
        CommissionMode.calculate(
            mode: commissionMode,
            mortgageType: mortgageType,
            yearsSinceSigning: yearsSinceSigning,
            amount: amountToAmortize,
            customPercent: customCommissionPercent,
            customFixed: customCommissionFixed
        )
    }

    var monthlyRate: Double { currentRate / 12 / 100 }
}

struct PartialAmortizationOption {
    let monthsSaved:    Int
    let interestSaved:  Double
    let commissionCost: Double
    let netSaving:      Double
    let newPayment:     Double
}

struct PartialAmortizationResult {
    let reduceTerm:    PartialAmortizationOption
    let reducePayment: PartialAmortizationOption
    let recommended:   PartialAmortizationResultType
}

enum PartialAmortizationResultType {
    case reduceTerm
    case reducePayment
}
