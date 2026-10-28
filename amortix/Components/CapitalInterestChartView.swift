import Charts
import SwiftUI

// Stacked bars per year showing how much of each year's payments goes to
// capital vs interest, plus a total summary. Built from a full monthly
// amortization table.
struct CapitalInterestChartView: View {
    let rows: [AmortizationRow]
    let code: String

    private struct YearBucket: Identifiable {
        let id:       Int      // year label
        let capital:  Double
        let interest: Double
    }

    // Aggregate monthly rows into yearly buckets. For long terms, group several
    // years per bar so the chart stays readable (max ~30 bars).
    private var buckets: [YearBucket] {
        guard !rows.isEmpty else { return [] }
        let totalYears = (rows.count + 11) / 12
        let groupSize  = max(1, (totalYears + 29) / 30)   // years per bar

        var map: [Int: (cap: Double, int: Double)] = [:]
        for row in rows {
            let year  = (row.id - 1) / 12 + 1
            let group = (year - 1) / groupSize + 1
            map[group, default: (0, 0)].cap += row.principal
            map[group, default: (0, 0)].int += row.interest
        }
        return map.keys.sorted().map { g in
            YearBucket(id: g, capital: map[g]!.cap, interest: map[g]!.int)
        }
    }

    private var totalCapital: Double { rows.reduce(0) { $0 + $1.principal } }
    private var totalInterest: Double { rows.reduce(0) { $0 + $1.interest } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.bold()).foregroundStyle(Color.brandBlue)
                Text("chart_capital_interest_title")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }

            Chart {
                ForEach(buckets) { b in
                    BarMark(x: .value("Año", b.id), y: .value("Capital", b.capital))
                        .foregroundStyle(by: .value("Tipo", "table_col_principal"))
                    BarMark(x: .value("Año", b.id), y: .value("Intereses", b.interest))
                        .foregroundStyle(by: .value("Tipo", "table_col_interest"))
                }
            }
            .chartForegroundStyleScale([
                "table_col_principal": Color.brandBlue,
                "table_col_interest":  Color.brandOrange.opacity(0.75)
            ])
            .chartLegend(position: .bottom, alignment: .leading) {
                HStack(spacing: 14) {
                    legendItem(color: .brandBlue, key: "table_col_principal")
                    legendItem(color: .brandOrange.opacity(0.75), key: "table_col_interest")
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self) {
                        AxisValueLabel { Text(d.asCompactCurrency(code)).font(.caption2) }
                    }
                }
            }
            .frame(height: 180)

            // Total summary
            HStack {
                summaryItem(key: "chart_total_capital", value: totalCapital, color: .brandBlue)
                Spacer()
                summaryItem(key: "chart_total_interest", value: totalInterest, color: .brandOrange)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendItem(color: Color, key: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(key).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func summaryItem(key: LocalizedStringKey, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.caption2).foregroundStyle(.secondary)
            Text(value.asCurrency(code)).font(.subheadline.bold()).foregroundStyle(color)
        }
    }
}
