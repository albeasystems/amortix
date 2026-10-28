import Charts
import SwiftUI

struct AmortizationChartView: View {
    let rows: [AmortizationRow]

    private var sampled: [AmortizationRow] {
        guard !rows.isEmpty else { return [] }
        let step = max(1, rows.count / 60)
        return stride(from: 0, to: rows.count, by: step).map { rows[$0] }
    }

    var body: some View {
        Chart {
            ForEach(sampled) { row in
                AreaMark(
                    x: .value("Período", row.id),
                    yStart: .value("Inicio", 0),
                    yEnd: .value("Intereses", row.interest)
                )
                .foregroundStyle(Color.brandOrange.opacity(0.5))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Período", row.id),
                    y: .value("Saldo", row.balance)
                )
                .foregroundStyle(Color.brandBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                if let d = value.as(Double.self) {
                    AxisValueLabel { Text(d.asCompactCurrency).font(.caption2) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 220)
    }
}
