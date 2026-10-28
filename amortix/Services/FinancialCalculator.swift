import Foundation

// Pure stateless financial engine — French amortization system
enum FinancialCalculator {

    // MARK: - Core formula
    // Cuota = C × [r(1+r)^n] / [(1+r)^n - 1]
    //
    // Valid for any non-zero rate. Only an exactly-zero rate needs the special
    // case: with `r > 0` as the guard, a negative rate used to fall into the
    // 0 % branch (C/n) while the schedule still charged negative interest, so
    // the loan was paid off months early and the totals disagreed.
    static func monthlyPayment(capital: Double, monthlyRate r: Double, months n: Int) -> Double {
        guard abs(r) > 1e-12 else { return capital / Double(n) }
        let exp = pow(1 + r, Double(n))
        return capital * (r * exp) / (exp - 1)
    }

    // MARK: - Variable rate
    /// Euríbor (or the reference index) + spread, floored at 0 %.
    ///
    /// The borrower never earns interest on a loan: Spain's Ley 5/2019
    /// (art. 21.4) states the remunerative interest can never be negative, and
    /// that is also how lenders elsewhere applied the negative-Euríbor years.
    /// Every place that turns index + spread into a rate goes through here so
    /// the calculator, the hints and the "with your numbers" sheets agree.
    static func variableRate(euribor: Double, spread: Double) -> Double {
        max(0, euribor + spread)
    }

    // MARK: - Exact repayment
    /// Runs a fixed payment month by month until the balance is gone.
    ///
    /// Use this, not `payment × months − capital`, whenever the payment does not
    /// fit the term exactly (shorter term after a prepayment, or an extra
    /// monthly amount): the last instalment is only the leftover balance, so
    /// multiplying a full payment by the month count overstates the interest
    /// by up to one payment.
    static func repay(
        capital: Double,
        payment: Double,
        monthlyRate r: Double,
        maxMonths: Int
    ) -> (months: Int, totalInterest: Double) {
        var balance  = capital
        var interest = 0.0
        var months   = 0
        while balance > 0.005, months < maxMonths {
            let i = balance * r
            let principal = min(payment - i, balance)
            guard principal > 0 else { break }   // payment no longer covers interest
            interest += i
            balance  -= principal
            months   += 1
        }
        return (months, interest)
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

    // MARK: - Amortization schedule by system (single rate)
    //
    // Ported from Capital's `amortizingLoan` so the three systems match:
    //   • French   — constant payment; principal grows over time.
    //   • Linear   — constant principal (capital/n); payment decreases.
    //   • American — interest-only each period; full principal as a final bullet.
    //
    // Each row carries its own `payment` (only constant for French), so the rest
    // of the app can read the first/last instalments directly off the schedule.
    static func amortizationSchedule(
        capital: Double,
        monthlyRate r: Double,
        months n: Int,
        system: AmortizationSystem
    ) -> [AmortizationRow] {
        guard n > 0 else { return [] }
        var rows: [AmortizationRow] = []
        rows.reserveCapacity(n)

        switch system {
        case .french:
            let payment = monthlyPayment(capital: capital, monthlyRate: r, months: n)
            var balance = capital
            for period in 1...n {
                let interest  = balance * r
                let principal = min(payment - interest, balance)
                balance = max(0, balance - principal)
                rows.append(AmortizationRow(id: period, payment: interest + principal,
                                            principal: principal, interest: interest,
                                            balance: balance))
            }

        case .linear:
            let principalPerPeriod = capital / Double(n)
            var balance = capital
            for period in 1...n {
                let interest  = balance * r
                let principal = min(principalPerPeriod, balance)
                balance = max(0, balance - principal)
                rows.append(AmortizationRow(id: period, payment: interest + principal,
                                            principal: principal, interest: interest,
                                            balance: balance))
            }

        case .american:
            for period in 1...n {
                let interest  = capital * r
                let principal = (period == n) ? capital : 0
                let balance   = (period == n) ? 0.0 : capital
                rows.append(AmortizationRow(id: period, payment: interest + principal,
                                            principal: principal, interest: interest,
                                            balance: balance))
            }
        }
        return rows
    }

    // MARK: - Full mortgage result
    static func mortgageResult(input: MortgageInput) -> MortgageResult {
        if input.mortgageType == .mixed {
            return mixedMortgageResult(input: input)
        }

        let r     = input.monthlyRate
        let n     = input.totalMonths
        let table = amortizationSchedule(
            capital: input.capital, monthlyRate: r, months: n, system: input.system
        )
        let totalInterest = table.reduce(0) { $0 + $1.interest }
        let totalCost     = input.capital + totalInterest
        return MortgageResult(
            monthlyPayment:    table.first?.payment ?? 0,   // first instalment (constant only for French)
            totalInterest:     totalInterest,
            totalCost:         totalCost,
            amortizationTable: table,
            mortgageType:      input.mortgageType,
            system:            input.system,
            paymentIsConstant: input.system == .french
        )
    }

    // MARK: - Mixed mortgage (two phases: fixed then variable)
    //
    // Phase 1 (fixed): pay at the fixed TIN, with the monthly payment computed
    // as if amortizing over the *whole* term. Phase 2 (variable): once the fixed
    // period ends, the outstanding balance is re-amortized over the remaining
    // months at Euríbor + spread, producing a new (estimated) payment.
    static func mixedMortgageResult(input: MortgageInput) -> MortgageResult {
        let n          = input.totalMonths
        let fixedMonths = min(max(1, input.fixedPeriodYears * 12), n)
        let remMonths   = n - fixedMonths

        // Phase 1 — fixed
        let rFixed   = input.tin / 12 / 100
        let payment1 = monthlyPayment(capital: input.capital, monthlyRate: rFixed, months: n)
        let phase1   = amortizationTable(
            capital: input.capital, monthlyPayment: payment1, monthlyRate: rFixed, months: fixedMonths
        )
        let balanceAfterFixed = phase1.last?.balance ?? input.capital

        // Phase 2 — variable
        let variableRate = variableRate(euribor: input.euribor, spread: input.spread)
        let rVar         = variableRate / 12 / 100
        var phase2: [AmortizationRow] = []
        var payment2 = 0.0
        if remMonths > 0, balanceAfterFixed > 0.01 {
            payment2 = monthlyPayment(capital: balanceAfterFixed, monthlyRate: rVar, months: remMonths)
            phase2 = amortizationTable(
                capital: balanceAfterFixed, monthlyPayment: payment2, monthlyRate: rVar, months: remMonths
            )
        }

        // Combine tables, renumbering periods
        var table = phase1
        for row in phase2 {
            table.append(AmortizationRow(
                id:        fixedMonths + row.id,
                payment:   row.payment,
                principal: row.principal,
                interest:  row.interest,
                balance:   row.balance
            ))
        }

        let totalCost     = payment1 * Double(fixedMonths) + payment2 * Double(remMonths)
        let totalInterest = totalCost - input.capital

        return MortgageResult(
            monthlyPayment:       payment1,
            totalInterest:        totalInterest,
            totalCost:            totalCost,
            amortizationTable:    table,
            mortgageType:         .mixed,
            fixedPhasePayment:    payment1,
            variablePhasePayment: payment2,
            fixedPhaseMonths:     fixedMonths,
            balanceAfterFixed:    balanceAfterFixed,
            variableRate:         variableRate
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

        // Option A — Reduce term (keep same monthly payment). Simulated rather
        // than `payment × newMonths − capital`: the last instalment is partial,
        // and counting it whole understated the saving by up to one payment.
        let shortened         = repay(capital: newCapital, payment: currentPayment,
                                      monthlyRate: r, maxMonths: n)
        let newMonths         = max(1, shortened.months)
        let monthsSaved       = max(0, n - newMonths)
        let interestSavedTerm = originalInterest - shortened.totalInterest
        let reduceTerm = PartialAmortizationOption(
            monthsSaved:     monthsSaved,
            newTermMonths:   newMonths,
            interestSaved:   interestSavedTerm,
            commissionCost:  commission,
            netSaving:       interestSavedTerm - commission,
            newPayment:      currentPayment,
            originalPayment: currentPayment,
            schedule:        partialYearlySchedule(capital: newCapital, rate: r,
                                                   payment: currentPayment, months: newMonths)
        )

        // Option B — Reduce payment (keep same remaining term)
        let newPayment       = monthlyPayment(capital: newCapital, monthlyRate: r, months: n)
        let interestSavedPay = originalInterest - (newPayment * Double(n) - newCapital)
        let reducePayment = PartialAmortizationOption(
            monthsSaved:     0,
            newTermMonths:   n,
            interestSaved:   interestSavedPay,
            commissionCost:  commission,
            netSaving:       interestSavedPay - commission,
            newPayment:      newPayment,
            originalPayment: currentPayment,
            schedule:        partialYearlySchedule(capital: newCapital, rate: r,
                                                   payment: newPayment, months: n)
        )

        let recommended: PartialAmortizationResultType =
            reduceTerm.netSaving >= reducePayment.netSaving ? .reduceTerm : .reducePayment

        return PartialAmortizationResult(
            reduceTerm:       reduceTerm,
            reducePayment:    reducePayment,
            recommended:      recommended,
            originalMonths:   n,
            amountAmortized:  input.amountToAmortize,
            newCapital:       newCapital,
            commission:       commission,
            originalInterest: originalInterest
        )
    }

    /// Generates a yearly summary schedule for partial amortization options.
    private static func partialYearlySchedule(
        capital: Double, rate: Double, payment: Double, months: Int
    ) -> [PartialAmortizationYearRow] {
        var rows: [PartialAmortizationYearRow] = []
        var balance = capital
        let totalYears = max(1, (months + 11) / 12)
        for year in 1...totalYears {
            let startMonth = (year - 1) * 12 + 1
            let endMonth   = min(year * 12, months)
            var yCapital  = 0.0
            var yInterest = 0.0
            for _ in startMonth...endMonth {
                let interest  = balance * rate
                let principal = min(payment - interest, balance)
                yInterest += interest
                yCapital  += principal
                balance    = max(0, balance - principal)
            }
            rows.append(PartialAmortizationYearRow(
                id:       year,
                payment:  yCapital + yInterest,   // last year's final instalment is partial
                capital:  yCapital,
                interest: yInterest,
                balance:  max(0, balance)
            ))
            if balance < 0.01 { break }
        }
        return rows
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

    // MARK: - Extra monthly payments
    // Formula: n_new = -ln(1 - C*r / (pmt+extra)) / ln(1+r)
    static func extraPaymentsResult(input: ExtraPaymentsInput) -> ExtraPaymentsResult {
        let r              = input.monthlyRate
        let n              = input.remainingMonths
        let currentPayment = monthlyPayment(capital: input.remainingCapital, monthlyRate: r, months: n)
        let effective      = currentPayment + input.extraMonthly

        // Simulated: the last instalment only clears the leftover balance, so
        // `effective × newMonths − capital` overstated the interest.
        let accelerated            = repay(capital: input.remainingCapital, payment: effective,
                                           monthlyRate: r, maxMonths: n)
        let newMonths              = max(1, accelerated.months)

        let monthsSaved            = max(0, n - newMonths)
        let totalInterestWithout   = currentPayment * Double(n) - input.remainingCapital
        let totalInterestWithExtra = accelerated.totalInterest
        let interestSaved          = max(0, totalInterestWithout - totalInterestWithExtra)

        // Compact schedule (sampled for performance)
        let schedule = extraPaymentsSchedule(
            capital: input.remainingCapital,
            payment: currentPayment,
            extra: input.extraMonthly,
            monthlyRate: r,
            months: newMonths
        )

        return ExtraPaymentsResult(
            currentPayment:         currentPayment,
            newPayoffMonths:        newMonths,
            monthsSaved:            monthsSaved,
            totalInterestWithout:   totalInterestWithout,
            totalInterestWithExtra: totalInterestWithExtra,
            interestSaved:          interestSaved,
            schedule:               schedule
        )
    }

    private static func extraPaymentsSchedule(
        capital: Double, payment: Double, extra: Double,
        monthlyRate r: Double, months: Int
    ) -> [ExtraPaymentsRow] {
        var rows: [ExtraPaymentsRow] = []
        let step    = max(1, months / 60)
        var balance = capital
        for period in 1...max(1, months) {
            let interest  = balance * r
            let principal = min(payment - interest + extra, balance)
            balance = max(0, balance - principal)
            if period % step == 0 || balance == 0 {
                rows.append(ExtraPaymentsRow(id: period, balance: balance,
                                             interest: interest, principal: principal))
            }
            if balance == 0 { break }
        }
        return rows
    }

    // MARK: - Stress test scenarios
    // Returns payment for a range of rate deltas (e.g. -2 to +5 pp)
    static func stressTestScenarios(
        capital: Double,
        months: Int,
        baseRate: Double,
        deltas: [Double] = [-2, -1, 0, 1, 2, 3, 4, 5]
    ) -> [StressScenario] {
        let basePayment = monthlyPayment(
            capital: capital,
            monthlyRate: baseRate / 12 / 100,
            months: months
        )
        return deltas.map { delta in
            let rate    = max(0.01, baseRate + delta)
            let payment = monthlyPayment(capital: capital,
                                         monthlyRate: rate / 12 / 100,
                                         months: months)
            return StressScenario(delta: delta, rate: rate,
                                  payment: payment, diff: payment - basePayment)
        }
    }
}
