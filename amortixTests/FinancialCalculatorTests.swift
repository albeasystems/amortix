//
//  FinancialCalculatorTests.swift
//  amortixTests
//
//  Checks the engine against closed-form formulas and against an independent
//  month-by-month simulation (written here, not borrowed from the engine), so a
//  shortcut in the engine cannot agree with itself.
//

import Foundation
import Testing
@testable import amortix

/// Reference simulation: pays a fixed amount until the balance is gone, with the
/// last instalment covering only what is left.
private func simulate(capital: Double, payment: Double, monthlyRate r: Double) -> (months: Int, interest: Double) {
    var balance = capital, interest = 0.0, months = 0
    while balance > 0.005 && months < 2_000 {
        let i = balance * r
        interest += i
        balance  -= min(payment - i, balance)
        months   += 1
    }
    return (months, interest)
}

private func close(_ a: Double, _ b: Double, _ tolerance: Double = 0.01) -> Bool { abs(a - b) <= tolerance }

struct MortgageSystemsTests {

    let capital = 200_000.0
    let r = 3.5 / 12 / 100
    let n = 360

    @Test func frenchPaymentMatchesReference() {
        let p = FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: r, months: n)
        #expect(close(p, 898.09))
    }

    @Test func frenchScheduleRepaysCapitalExactly() {
        let res = FinancialCalculator.mortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 3.5, mortgageType: .fixed, system: .french))
        #expect(res.amortizationTable.last!.balance < 0.005)
        #expect(close(res.amortizationTable.reduce(0) { $0 + $1.principal }, capital))
    }

    @Test func linearInterestMatchesClosedForm() {
        let res = FinancialCalculator.mortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 3.5, mortgageType: .fixed, system: .linear))
        #expect(close(res.totalInterest, r * capital * Double(n + 1) / 2, 0.5))
        #expect(close(res.monthlyPayment, capital / Double(n) + capital * r))
    }

    @Test func americanIsInterestOnlyWithFinalBullet() {
        let res = FinancialCalculator.mortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 3.5, mortgageType: .fixed, system: .american))
        #expect(close(res.totalInterest, capital * r * Double(n), 0.5))
        #expect(close(res.amortizationTable.last!.principal, capital))
    }

    @Test func variableUsesIndexPlusSpreadNotTIN() {
        let res = FinancialCalculator.mortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 9, mortgageType: .variable, system: .french, euribor: 3, spread: 1))
        #expect(close(res.monthlyPayment, FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: 4.0 / 1200, months: n)))
    }

    @Test func mixedTotalsMatchItsOwnTable() {
        let res = FinancialCalculator.mixedMortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 2.5, mortgageType: .mixed, system: .french, euribor: 3, spread: 1, fixedPeriodYears: 5))
        #expect(res.amortizationTable.last!.balance < 0.005)
        #expect(close(res.totalInterest, res.amortizationTable.reduce(0) { $0 + $1.interest }, 1))
    }

    @Test func mixedWithFixedPeriodLongerThanTermDoesNotBreak() {
        let res = FinancialCalculator.mixedMortgageResult(input: MortgageInput(capital: capital, years: 30, tin: 2.5, mortgageType: .mixed, euribor: 3, spread: 1, fixedPeriodYears: 40))
        #expect(res.amortizationTable.count == n)
        #expect(res.amortizationTable.last!.balance < 0.005)
    }
}

struct VariableRateFloorTests {

    @Test func indexPlusSpreadIsFlooredAtZero() {
        #expect(FinancialCalculator.variableRate(euribor: -2, spread: 1) == 0)
        #expect(FinancialCalculator.variableRate(euribor: -0.5, spread: 1) == 0.5)
    }

    @Test func negativeIndexBehavesAsZeroPercentLoan() {
        // Euríbor −2 % + 1 % used to price as 0 % but schedule at −1 %, paying
        // the loan off in row 315 of 360.
        let res = FinancialCalculator.mortgageResult(input: MortgageInput(capital: 200_000, years: 30, tin: 3.5, mortgageType: .variable, system: .french, euribor: -2, spread: 1))
        #expect(close(res.totalInterest, 0))
        #expect(close(res.monthlyPayment, 200_000 / 360))
        #expect(res.amortizationTable.firstIndex { $0.balance < 0.005 } == 359)
    }

    @Test func mixedVariablePhaseIsFloored() {
        let res = FinancialCalculator.mixedMortgageResult(input: MortgageInput(capital: 200_000, years: 30, tin: 2.5, mortgageType: .mixed, euribor: -3, spread: 1, fixedPeriodYears: 5))
        #expect(res.variableRate == 0)
        #expect(res.amortizationTable.last!.balance < 0.005)
    }

    @Test func euriborReviewScenarioIsFloored() {
        let input = EuriborReviewInput(remainingCapital: 150_000, remainingMonths: 240, spread: 0.5, currentEuribor: 0.5, scenarioDelta: -2)
        #expect(input.simulatedRate == 0)
        let res = FinancialCalculator.euriborReviewResult(input: input)
        #expect(close(res.simulatedPayment, 150_000 / 240))
    }

    @Test func negativeMonthlyRateStillAmortizesOverTheFullTerm() {
        // The engine itself no longer mis-prices a negative rate, should one
        // ever reach it from a path that does not go through the floor.
        let rows = FinancialCalculator.amortizationSchedule(capital: 100_000, monthlyRate: -0.001, months: 120, system: .french)
        #expect(rows.firstIndex { $0.balance < 0.005 } == 119)
    }
}

struct PrepaymentTests {

    let capital = 150_000.0, months = 240, rate = 3.5
    var r: Double { rate / 12 / 100 }

    @Test func reduceTermSavingMatchesExactSimulation() {
        let res = FinancialCalculator.partialAmortizationResult(input: PartialAmortizationInput(
            remainingCapital: capital, remainingMonths: months, currentRate: rate, amountToAmortize: 20_000, commissionMode: .none))
        let pay  = FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: r, months: months)
        let sim  = simulate(capital: 130_000, payment: pay, monthlyRate: r)
        let originalInterest = pay * Double(months) - capital
        #expect(res.reduceTerm.newTermMonths == sim.months)
        // Was 17,407.40 against an exact 17,796.83 (−389 €).
        #expect(close(res.reduceTerm.interestSaved, originalInterest - sim.interest))
    }

    @Test func reducePaymentSavingIsExact() {
        let res = FinancialCalculator.partialAmortizationResult(input: PartialAmortizationInput(
            remainingCapital: capital, remainingMonths: months, currentRate: rate, amountToAmortize: 20_000, commissionMode: .none))
        let pay    = FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: r, months: months)
        let newPay = FinancialCalculator.monthlyPayment(capital: 130_000, monthlyRate: r, months: months)
        #expect(close(res.reducePayment.interestSaved, (pay * Double(months) - capital) - (newPay * Double(months) - 130_000), 0.05))
    }

    @Test func yearlySchedulePaymentsAddUpToWhatIsPaid() {
        let res = FinancialCalculator.partialAmortizationResult(input: PartialAmortizationInput(
            remainingCapital: capital, remainingMonths: months, currentRate: rate, amountToAmortize: 20_000, commissionMode: .none))
        let schedule = res.reduceTerm.schedule
        let paid = schedule.reduce(0) { $0 + $1.payment }
        let interest = schedule.reduce(0) { $0 + $1.interest }
        #expect(close(paid, 130_000 + interest, 0.05))
        #expect(schedule.last!.balance < 0.5)
    }

    @Test func extraPaymentsMatchExactSimulation() {
        let res = FinancialCalculator.extraPaymentsResult(input: ExtraPaymentsInput(
            remainingCapital: capital, remainingMonths: months, currentRate: rate, extraMonthly: 100))
        let pay = FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: r, months: months)
        let sim = simulate(capital: capital, payment: pay + 100, monthlyRate: r)
        #expect(res.newPayoffMonths == sim.months)
        // Was 49,807.55 against an exact 49,742.88 (+65 €).
        #expect(close(res.totalInterestWithExtra, sim.interest))
        #expect(close(res.interestSaved, (pay * Double(months) - capital) - sim.interest))
    }

    @Test func prepayingAlmostEverythingLeavesAOneMonthTerm() {
        let res = FinancialCalculator.partialAmortizationResult(input: PartialAmortizationInput(
            remainingCapital: capital, remainingMonths: months, currentRate: rate, amountToAmortize: capital - 1, commissionMode: .none))
        #expect(res.reduceTerm.newTermMonths == 1)
    }
}
