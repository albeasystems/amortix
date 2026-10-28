import SwiftUI

// MARK: - KPI dynamic scenario
//
// Carries the *real* numbers of the calculation the user just performed, so
// the ⓘ info sheet can show a "Con tus números" breakdown (CalculoCompuesto
// style) instead of only a generic example.
//
// All fields are optional: each calculator fills in the ones it knows about
// and `breakdown(for:)` builds the relevant lines per KPI key. If a KPI has no
// data available, it returns [] and the section is hidden.

struct KPIBreakdownLine: Identifiable {
    let id = UUID()
    let labelKey:   LocalizedStringKey
    let value:      String
    var highlighted = false
}

struct KPIScenario {
    var code: String = "EUR"

    // Mortgage
    var capital:             Double?
    var years:               Int?
    var rate:                Double?   // effective annual %
    var monthlyPayment:      Double?
    var totalInterest:       Double?
    var totalCost:           Double?
    var firstMonthInterest:  Double?
    var firstMonthPrincipal: Double?

    // Mixed
    var fixedYears:        Int?
    var fixedPayment:      Double?
    var balanceAfterFixed: Double?
    var variableRate:      Double?
    var variablePayment:   Double?

    // Partial amortization / extra payments
    var remainingCapital: Double?
    var amountAmortized:  Double?
    var monthsSaved:      Int?
    var interestSaved:    Double?
    var commission:       Double?
    var netSaving:        Double?
    var newPayment:       Double?
    var originalPayment:  Double?

    // Euribor review
    var currentPayment:    Double?
    var simulatedPayment:  Double?
    var monthlyDifference: Double?
    var annualDifference:  Double?

    // Invest vs amortize
    var amount:         Double?
    var amortizeSaving: Double?
    var investGain:     Double?
    var expectedReturn: Double?
    var horizonYears:   Int?

    // MARK: - Breakdown builder

    func breakdown(for key: String) -> [KPIBreakdownLine] {
        let c = code
        func money(_ v: Double) -> String { v.asCurrency(c) }
        func pct(_ v: Double) -> String { v.asPercentage }
        func months(_ m: Int) -> String {
            let y = m / 12, mo = m % 12
            if y > 0 && mo > 0 { return "\(y) a \(mo) m" }
            if y > 0 { return "\(y) a" }
            return "\(mo) m"
        }

        switch key {

        // MARK: Input fields — live "Con tus números" from current inputs

        case "input_capital":
            guard let capital else { return [] }
            var lines: [KPIBreakdownLine] = [
                .init(labelKey: "calculator_capital", value: money(capital), highlighted: true)
            ]
            if let years          { lines.append(.init(labelKey: "calculator_years", value: "\(years)")) }
            if let rate           { lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate))) }
            if let monthlyPayment { lines.append(.init(labelKey: "calculator_result_monthly", value: money(monthlyPayment))) }
            return lines

        case "input_years":
            guard let years else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let capital        { lines.append(.init(labelKey: "calculator_capital", value: money(capital))) }
            lines.append(.init(labelKey: "calculator_years", value: "\(years)", highlighted: true))
            if let rate           { lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate))) }
            if let monthlyPayment { lines.append(.init(labelKey: "calculator_result_monthly", value: money(monthlyPayment))) }
            return lines

        case "input_rate":
            guard let rate else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let capital        { lines.append(.init(labelKey: "calculator_capital", value: money(capital))) }
            if let years          { lines.append(.init(labelKey: "calculator_years", value: "\(years)")) }
            lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate), highlighted: true))
            if let monthlyPayment { lines.append(.init(labelKey: "calculator_result_monthly", value: money(monthlyPayment))) }
            return lines

        case "monthly_payment":
            guard let pmt = monthlyPayment else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let capital { lines.append(.init(labelKey: "calculator_capital", value: money(capital))) }
            if let years   { lines.append(.init(labelKey: "calculator_years", value: "\(years)")) }
            if let rate    { lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate))) }
            lines.append(.init(labelKey: "calculator_result_monthly", value: money(pmt), highlighted: true))
            if let i = firstMonthInterest { lines.append(.init(labelKey: "kpi_label_first_interest", value: money(i))) }
            if let p = firstMonthPrincipal { lines.append(.init(labelKey: "kpi_label_first_principal", value: money(p))) }
            return lines

        case "total_interest":
            guard let ti = totalInterest else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let totalCost { lines.append(.init(labelKey: "calculator_result_total_cost", value: money(totalCost))) }
            if let capital   { lines.append(.init(labelKey: "calculator_capital", value: "− \(money(capital))")) }
            lines.append(.init(labelKey: "calculator_result_total_interest", value: money(ti), highlighted: true))
            return lines

        case "total_cost":
            guard let tc = totalCost else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let capital       { lines.append(.init(labelKey: "calculator_capital", value: money(capital))) }
            if let totalInterest { lines.append(.init(labelKey: "calculator_result_total_interest", value: "+ \(money(totalInterest))")) }
            lines.append(.init(labelKey: "calculator_result_total_cost", value: money(tc), highlighted: true))
            return lines

        case "mixed_fixed_payment":
            guard let fp = fixedPayment else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let capital    { lines.append(.init(labelKey: "calculator_capital", value: money(capital))) }
            if let rate       { lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate))) }
            if let fixedYears { lines.append(.init(labelKey: "calculator_fixed_period_years", value: "\(fixedYears)")) }
            lines.append(.init(labelKey: "calculator_result_mixed_fixed", value: money(fp), highlighted: true))
            return lines

        case "mixed_variable_payment":
            guard let vp = variablePayment else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let b = balanceAfterFixed { lines.append(.init(labelKey: "kpi_label_balance_after_fixed", value: money(b))) }
            if let variableRate { lines.append(.init(labelKey: "kpi_label_variable_rate", value: pct(variableRate))) }
            lines.append(.init(labelKey: "calculator_result_mixed_variable", value: money(vp), highlighted: true))
            return lines

        case "months_saved":
            guard let ms = monthsSaved else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let amountAmortized { lines.append(.init(labelKey: "partial_amount", value: money(amountAmortized))) }
            lines.append(.init(labelKey: "kpi_months_saved_title", value: months(ms), highlighted: true))
            return lines

        case "interest_saved":
            guard let isv = interestSaved else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let amountAmortized { lines.append(.init(labelKey: "partial_amount", value: money(amountAmortized))) }
            lines.append(.init(labelKey: "kpi_interest_saved_title", value: money(isv), highlighted: true))
            return lines

        case "net_saving":
            guard let ns = netSaving else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let interestSaved { lines.append(.init(labelKey: "kpi_interest_saved_title", value: money(interestSaved))) }
            if let commission    { lines.append(.init(labelKey: "kpi_commission_title", value: "− \(money(commission))")) }
            lines.append(.init(labelKey: "kpi_net_saving_title", value: money(ns), highlighted: true))
            return lines

        case "commission":
            guard let cm = commission else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let amountAmortized { lines.append(.init(labelKey: "partial_amount", value: money(amountAmortized))) }
            lines.append(.init(labelKey: "kpi_commission_title", value: money(cm), highlighted: true))
            return lines

        case "new_payment":
            guard let np = newPayment else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let originalPayment { lines.append(.init(labelKey: "partial_new_payment", value: money(originalPayment))) }
            lines.append(.init(labelKey: "kpi_new_payment_title", value: money(np), highlighted: true))
            return lines

        case "euribor_diff_monthly":
            guard let md = monthlyDifference else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let currentPayment   { lines.append(.init(labelKey: "euribor_current_payment", value: money(currentPayment))) }
            if let simulatedPayment { lines.append(.init(labelKey: "euribor_simulated_payment", value: money(simulatedPayment))) }
            lines.append(.init(labelKey: "euribor_difference_monthly", value: md.currencyDifference(code: c), highlighted: true))
            if let annualDifference { lines.append(.init(labelKey: "euribor_difference_annual", value: annualDifference.currencyDifference(code: c))) }
            return lines

        case "amortize_saving":
            guard let asv = amortizeSaving else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let amount        { lines.append(.init(labelKey: "kpi_label_amount", value: money(amount))) }
            if let rate          { lines.append(.init(labelKey: "kpi_label_rate", value: pct(rate))) }
            if let horizonYears  { lines.append(.init(labelKey: "calculator_years", value: "\(horizonYears)")) }
            lines.append(.init(labelKey: "kpi_amortize_saving_title", value: money(asv), highlighted: true))
            return lines

        case "invest_gain":
            guard let ig = investGain else { return [] }
            var lines: [KPIBreakdownLine] = []
            if let amount         { lines.append(.init(labelKey: "kpi_label_amount", value: money(amount))) }
            if let expectedReturn { lines.append(.init(labelKey: "kpi_label_return", value: pct(expectedReturn))) }
            if let horizonYears   { lines.append(.init(labelKey: "calculator_years", value: "\(horizonYears)")) }
            lines.append(.init(labelKey: "kpi_invest_gain_title", value: money(ig), highlighted: true))
            return lines

        default:
            return []
        }
    }
}
