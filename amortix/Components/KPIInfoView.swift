import Charts
import SwiftUI

struct KPIInfoView: View {
    let infoKey: String
    var scenario: KPIScenario? = nil
    @Environment(\.dismiss) private var dismiss

    private var info: KPIInfo? { KPIInfo.find(infoKey) }

    private var breakdownLines: [KPIBreakdownLine] {
        scenario?.breakdown(for: infoKey) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let info {
                        // Explanation
                        explanationCard(info: info)

                        // Formula (optional)
                        if let formulaKey = info.formulaKey {
                            formulaCard(key: formulaKey)
                        }

                        // "Con tus números" — real values of the current calculation
                        if !breakdownLines.isEmpty {
                            yourNumbersCard(lines: breakdownLines)
                        }

                        // Example — only when there are no real numbers to show
                        if breakdownLines.isEmpty {
                            exampleCard(info: info)
                        }

                        // Inline chart for numeric KPIs
                        if let chart = chartView(for: infoKey) {
                            chart
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(info?.titleKey ?? LocalizedStringKey(infoKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("general_close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private func explanationCard(info: KPIInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("kpi_section_what", systemImage: "lightbulb.fill")
                .font(.caption.bold())
                .foregroundStyle(Color.brandBlue)
            Text(info.explanationKey)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formulaCard(key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("kpi_section_formula", systemImage: "function")
                .font(.caption.bold())
                .foregroundStyle(Color.brandOrange)
            Text(key)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Color.brandOrange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brandOrange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func yourNumbersCard(lines: [KPIBreakdownLine]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("kpi_section_your_numbers", systemImage: "person.fill.checkmark")
                .font(.caption.bold())
                .foregroundStyle(Color.brandGreen)
            VStack(spacing: 6) {
                ForEach(lines) { line in
                    HStack {
                        Text(line.labelKey)
                            .font(line.highlighted ? .subheadline.bold() : .subheadline)
                            .foregroundStyle(line.highlighted ? .primary : .secondary)
                        Spacer()
                        Text(line.value)
                            .font(line.highlighted ? .subheadline.bold() : .subheadline)
                            .foregroundStyle(line.highlighted ? Color.brandGreen : .primary)
                    }
                    if line.id != lines.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brandGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func exampleCard(info: KPIInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("kpi_section_example", systemImage: "pencil.and.list.clipboard")
                .font(.caption.bold())
                .foregroundStyle(Color.brandTeal)
            Text(info.exampleKey)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brandTeal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Inline charts per KPI type

    private func chartView(for key: String) -> AnyView? {
        switch key {
        case "monthly_payment", "total_interest", "total_cost",
             "input_capital", "input_years", "input_rate":
            AnyView(amortizationPreviewChart)
        case "months_saved", "interest_saved", "net_saving":
            AnyView(savingsComparisonChart)
        case "euribor_diff_monthly":
            AnyView(euriborScenarioChart)
        case "amortize_saving", "invest_gain":
            AnyView(investComparisonChart)
        default:
            nil
        }
    }

    // Amortization preview: balance over time — uses the user's own numbers when
    // available, otherwise a generic 200k / 3.5% / 30-year example.
    private var amortizationPreviewChart: some View {
        let capital = scenario?.capital.flatMap { $0 > 0 ? $0 : nil } ?? 200_000
        let rate    = scenario?.rate.flatMap { $0 > 0 ? $0 : nil } ?? 3.5
        let years   = scenario?.years.flatMap { $0 > 0 ? $0 : nil } ?? 30
        let rows = previewRows(capital: capital, rate: rate, years: years)
        return VStack(alignment: .leading, spacing: 8) {
            Label("kpi_chart_label", systemImage: "chart.line.downtrend.xyaxis")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Chart {
                ForEach(rows, id: \.id) { row in
                    AreaMark(x: .value("Mes", row.id), yStart: .value("I0", 0), yEnd: .value("I", row.interest))
                        .foregroundStyle(Color.brandOrange.opacity(0.4))
                    LineMark(x: .value("Mes", row.id), y: .value("B", row.balance))
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .frame(height: 160)
            // X axis is the payment number (months) — label it so the ticks read clearly.
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text("general_months")
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self) { AxisValueLabel { Text(d.asCompactCurrency).font(.caption2) } }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Reduce term vs reduce payment comparison bars
    private var savingsComparisonChart: some View {
        let data: [(String, Double)] = [
            ("▸ Reduce term",    18_450),
            ("▸ Reduce payment", 12_800),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Label("kpi_chart_label", systemImage: "chart.bar.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Chart(data, id: \.0) { item in
                BarMark(x: .value("Saving (€)", item.1), y: .value("Option", item.0))
                    .foregroundStyle(item.0.contains("term") ? Color.brandGreen : Color.brandTeal)
                    .annotation(position: .trailing) {
                        Text(item.1.asCompactCurrency).font(.caption2)
                    }
            }
            .frame(height: 80)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Euribor scenario: current vs +1pt vs +2pt vs -1pt
    private var euriborScenarioChart: some View {
        let deltas: [Double] = [-1, 0, 1, 2]
        let base = FinancialCalculator.monthlyPayment(capital: 150_000, monthlyRate: 3.5 / 12 / 100, months: 240)
        let data = deltas.map { d -> (String, Double) in
            let rate = (3.5 + d) / 12 / 100
            let pmt  = FinancialCalculator.monthlyPayment(capital: 150_000, monthlyRate: rate, months: 240)
            return ("\(d >= 0 ? "+" : "")\(Int(d))%", pmt - base)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label("kpi_chart_label", systemImage: "waveform.path.ecg")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Chart(data, id: \.0) { item in
                BarMark(x: .value("Δ", item.0), y: .value("€/mes", item.1))
                    .foregroundStyle(item.1 >= 0 ? Color.brandRed.opacity(0.7) : Color.brandGreen.opacity(0.7))
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Invest vs amortize at different horizons
    private var investComparisonChart: some View {
        let horizons = [5, 10, 15, 20]
        let amount   = 20_000.0
        let data: [(Int, Double, Double)] = horizons.map { h in
            let amortize = amount * (pow(1 + 3.5 / 100, Double(h)) - 1)
            let invest   = amount * (pow(1 + 7.0 / 100, Double(h)) - 1)
            return (h, amortize, invest)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label("kpi_chart_label", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Chart {
                ForEach(data, id: \.0) { item in
                    LineMark(x: .value("Años", item.0), y: .value("€", item.1), series: .value("T", "amortize"))
                        .foregroundStyle(Color.brandBlue)
                    LineMark(x: .value("Años", item.0), y: .value("€", item.2), series: .value("T", "invest"))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helper
    private func previewRows(capital: Double, rate: Double, years: Int) -> [AmortizationRow] {
        let r   = rate / 12 / 100
        let n   = years * 12
        let pmt = FinancialCalculator.monthlyPayment(capital: capital, monthlyRate: r, months: n)
        let all = FinancialCalculator.amortizationTable(capital: capital, monthlyPayment: pmt, monthlyRate: r, months: n)
        let step = max(1, all.count / 48)
        return stride(from: 0, to: all.count, by: step).map { all[$0] }
    }
}

#Preview {
    KPIInfoView(infoKey: "monthly_payment")
}
