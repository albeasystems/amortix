import Foundation

// MARK: - Euribor Review

struct EuriborReviewInput {
    var remainingCapital:  Double = 150_000
    var remainingMonths:   Int    = 240
    var spread:            Double = 1.0
    var currentEuribor:    Double = 3.0
    var scenarioDelta:     Double = 0

    var currentRate:    Double { FinancialCalculator.variableRate(euribor: currentEuribor, spread: spread) }
    var simulatedRate:  Double { FinancialCalculator.variableRate(euribor: currentEuribor + scenarioDelta, spread: spread) }
}

struct EuriborReviewResult {
    let currentPayment:    Double
    let simulatedPayment:  Double
    let monthlyDifference: Double
    let annualDifference:  Double
}

// MARK: - Invest vs Amortize (Premium)

struct InvestVsAmortizeInput {
    var amount:         Double = 20_000
    var mortgageTin:    Double = 3.5
    var expectedReturn: Double = 7.0
    var horizonYears:   Int    = 10
}

struct InvestVsAmortizeResult {
    let amortizeSaving: Double
    let investGain:     Double
    let recommendation: InvestRecommendation
}

enum InvestRecommendation {
    case amortize
    case invest
}
