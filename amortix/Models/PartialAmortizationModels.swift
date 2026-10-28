import Foundation

// MARK: - Yearly amortization row (for the table and charts)
struct PartialAmortizationYearRow: Identifiable {
    let id:       Int     // 1-based year number
    let payment:  Double  // total payments this year (sum of monthly)
    let capital:  Double  // capital repaid this year
    let interest: Double  // interest paid this year
    let balance:  Double  // outstanding balance at end of year
}

// MARK: - Option (reduce term OR reduce payment)
struct PartialAmortizationOption {
    let monthsSaved:     Int     // months saved vs original term (0 for reducePayment)
    let newTermMonths:   Int     // new remaining term in months
    let interestSaved:   Double
    let commissionCost:  Double
    let netSaving:       Double
    let newPayment:      Double  // monthly payment after amortization
    let originalPayment: Double  // monthly payment before amortization
    let schedule:        [PartialAmortizationYearRow]
}

// MARK: - Full result
struct PartialAmortizationResult {
    let reduceTerm:       PartialAmortizationOption
    let reducePayment:    PartialAmortizationOption
    let recommended:      PartialAmortizationResultType
    // Metadata for narrative explanation
    let originalMonths:   Int
    let amountAmortized:  Double
    let newCapital:       Double
    let commission:       Double
    let originalInterest: Double
}

enum PartialAmortizationResultType {
    case reduceTerm
    case reducePayment
}

// MARK: - Input
struct PartialAmortizationInput {
    var remainingCapital:         Double         = 150_000
    var remainingMonths:          Int            = 240
    var currentRate:              Double         = 3.5
    var amountToAmortize:         Double         = 20_000
    var commissionMode:           CommissionMode = .none
    var mortgageType:             MortgageType   = .variable
    var yearsSinceSigning:        Int            = 5
    var customCommissionPercent:  Double         = 0
    var customCommissionFixed:    Double         = 0
    var country:                  CountryMarket  = .spain

    var commission: Double {
        CommissionMode.calculate(
            mode: commissionMode,
            mortgageType: mortgageType,
            yearsSinceSigning: yearsSinceSigning,
            amount: amountToAmortize,
            customPercent: customCommissionPercent,
            customFixed: customCommissionFixed,
            country: country,
            monthlyRate: monthlyRate,
            remainingMonths: remainingMonths
        )
    }

    var monthlyRate: Double { currentRate / 12 / 100 }
}
