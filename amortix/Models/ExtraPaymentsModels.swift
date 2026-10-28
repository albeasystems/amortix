import Foundation

struct ExtraPaymentsInput {
    var remainingCapital:  Double = 150_000
    var remainingMonths:   Int    = 240
    var currentRate:       Double = 3.5
    var extraMonthly:      Double = 100

    var monthlyRate: Double { currentRate / 12 / 100 }
}

struct ExtraPaymentsResult {
    let currentPayment:         Double
    let newPayoffMonths:        Int
    let monthsSaved:            Int
    let totalInterestWithout:   Double
    let totalInterestWithExtra: Double
    let interestSaved:          Double
    let schedule: [ExtraPaymentsRow]
}

struct ExtraPaymentsRow: Identifiable {
    let id:         Int      // period
    let balance:    Double
    let interest:   Double
    let principal:  Double
}

// MARK: - Stress Test

struct StressScenario: Identifiable {
    let id      = UUID()
    let delta:   Double   // rate change in percentage points
    let rate:    Double   // resulting rate
    let payment: Double
    let diff:    Double   // vs current payment
}
