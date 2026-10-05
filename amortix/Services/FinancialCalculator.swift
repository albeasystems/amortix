import Foundation

// Pure stateless financial engine — French amortization system
enum FinancialCalculator {

    // MARK: - Core formula
    // Cuota = C × [r(1+r)^n] / [(1+r)^n - 1]
    static func monthlyPayment(capital: Double, monthlyRate r: Double, months n: Int) -> Double {
        guard r > 0 else { return capital / Double(n) }
        let exp = pow(1 + r, Double(n))
        return capital * (r * exp) / (exp - 1)
    }

    // MARK: - Amortization table
    static func amortizationTable(
        capital: Double,
        monthlyPayment payment: Double,
        monthlyRate r: Double,
        months: Int
    ) -> [AmortizationRow] {
        var rows: [AmortizationRow] = []
        rows.reserveCapacity(months)
        var balance = capital

        for period in 1...months {
            let interest  = balance * r
            let principal = min(payment - interest, balance)
            balance = max(0, balance - principal)
            rows.append(AmortizationRow(
                id:        period,
                payment:   payment,
                principal: principal,
                interest:  interest,
                balance:   balance
            ))
        }
        return rows
    }

    // MARK: - Full mortgage result
    static func mortgageResult(input: MortgageInput) -> MortgageResult {
        let r       = input.monthlyRate
        let n       = input.totalMonths
        let payment = monthlyPayment(capital: input.capital, monthlyRate: r, months: n)
        let table   = amortizationTable(
            capital: input.capital, monthlyPayment: payment, monthlyRate: r, months: n
        )
        let totalCost     = payment * Double(n)
        let totalInterest = totalCost - input.capital
        return MortgageResult(
            monthlyPayment:    payment,
            totalInterest:     totalInterest,
            totalCost:         totalCost,
            amortizationTable: table
        )
    }

    // MARK: - Partial amortization
    static func partialAmortizationResult(input: PartialAmortizationInput) -> PartialAmortizationResult {
        let r          = input.monthlyRate
        let n          = input.remainingMonths
        let newCapital = input.remainingCapital - input.amountToAmortize
        let commission = input.commission

        let currentPayment   = monthlyPayment(capital: input.remainingCapital, monthlyRate: r, months: n)
        let originalInterest = currentPayment * Double(n) - input.remainingCapital

        // Option A — Reduce term (keep same payment)
        let newMonths: Int = {
            guard r > 0, currentPayment > newCapital * r else { return 1 }
            return max(1, Int(ceil(-log(1 - newCapital * r / currentPayment) / log(1 + r))))
        }()
        let monthsSaved       = max(0, n - newMonths)
        let interestSavedTerm = originalInterest - (currentPayment * Double(newMonths) - newCapital)
        let reduceTerm = PartialAmortizationOption(
            monthsSaved:    monthsSaved,
            interestSaved:  interestSavedTerm,
            commissionCost: commission,
            netSaving:      interestSavedTerm - commission,
            newPayment:     currentPayment
        )

        // Option B — Reduce payment (keep same term)
        let newPayment       = monthlyPayment(capital: newCapital, monthlyRate: r, months: n)
        let interestSavedPay = originalInterest - (newPayment * Double(n) - newCapital)
        let reducePayment = PartialAmortizationOption(
            monthsSaved:    0,
            interestSaved:  interestSavedPay,
            commissionCost: commission,
            netSaving:      interestSavedPay - commission,
            newPayment:     newPayment
        )

        let recommended: PartialAmortizationResultType =
            reduceTerm.netSaving >= reducePayment.netSaving ? .reduceTerm : .reducePayment

        return PartialAmortizationResult(
            reduceTerm:    reduceTerm,
            reducePayment: reducePayment,
            recommended:   recommended
        )
    }

    // MARK: - Euribor review
    static func euriborReviewResult(input: EuriborReviewInput) -> EuriborReviewResult {
        let n          = input.remainingMonths
        let currentR   = input.currentRate   / 12 / 100
        let simulatedR = input.simulatedRate / 12 / 100

        let currentPayment   = monthlyPayment(capital: input.remainingCapital, monthlyRate: currentR,   months: n)
        let simulatedPayment = monthlyPayment(capital: input.remainingCapital, monthlyRate: simulatedR, months: n)
        let diff             = simulatedPayment - currentPayment

        return EuriborReviewResult(
            currentPayment:    currentPayment,
            simulatedPayment:  simulatedPayment,
            monthlyDifference: diff,
            annualDifference:  diff * 12
        )
    }

    // MARK: - Invest vs amortize (Premium)
    // Both options use compound growth for a fair comparison.
    // Amortize "return" = guaranteed TIN rate; invest return = expected market rate.
    static func investVsAmortizeResult(input: InvestVsAmortizeInput) -> InvestVsAmortizeResult {
        let h              = Double(input.horizonYears)
        let amortizeSaving = input.amount * (pow(1 + input.mortgageTin / 100, h) - 1)
        let investGain     = input.amount * (pow(1 + input.expectedReturn / 100, h) - 1)
        let recommendation: InvestRecommendation = investGain > amortizeSaving ? .invest : .amortize

        return InvestVsAmortizeResult(
            amortizeSaving: amortizeSaving,
            investGain:     investGain,
            recommendation: recommendation
        )
    }
}
