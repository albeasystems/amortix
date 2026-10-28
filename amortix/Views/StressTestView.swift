import Charts
import SwiftUI

struct StressTestView: View {
    @AppStorage("selectedCountry")   private var selectedCountry: String = CountryMarket.spain.rawValue

    @State private var capitalText      = "100000"
    @State private var yearsText        = "25"
    @State private var extraMonthsText  = "0"
    @State private var rateText         = "3.50"

    private var totalMonths: Int {
        let y = Int(yearsText)       ?? 0
        let m = Int(extraMonthsText) ?? 0
        return max(1, y * 12 + m)
    }
    @State private var scenarios:  [StressScenario]    = []
    @State private var validationError: LocalizedStringKey?

    private var currencyCode: String {
        CountryMarket(rawValue: selectedCountry)?.currencyCode ?? "EUR"
    }

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 14) {

                AmountFieldCard(
                    labelKey:     "partial_remaining_capital",
                    systemImage:  "house.fill",
                    text:         $capitalText,
                    currencyCode: currencyCode,
                    infoKey:      "input_remaining_capital"
                )

                TimePickerCard(
                    labelKey:    "partial_time_remaining",
                    systemImage: "calendar",
                    yearsText:   $yearsText,
                    monthsText:  $extraMonthsText,
                    accentColor: .brandBlue,
                    infoKey:     "input_months"
                )

                RateSliderCard(
                    labelKey:    "stress_base_rate",
                    systemImage: "percent",
                    text:        $rateText,
                    range:       0.05...15,
                    step:        0.05,
                    accentColor: .brandRed,
                    infoKey:     "input_stress_rate"
                )

                Button {
                    HapticService.impact()
                    calculate()
                    scrollToResults(proxy)
                } label: {
                    Text("stress_btn_calculate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandRed)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Scroll anchor — pressing Calculate jumps the view here
                Color.clear.frame(height: 0).id("results")

                if !scenarios.isEmpty {
                    scenariosTable
                    scenariosChart
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

            }
            .padding(16)
            .adaptiveMaxWidth()
            .frame(maxWidth: .infinity)
          }
          .scrollDismissesKeyboard(.interactively)
          .animation(.spring(response: 0.4, dampingFraction: 1), value: scenarios.count)
          .alert(validationError ?? "error_invalid_capital", isPresented: Binding(
              get: { validationError != nil },
              set: { if !$0 { validationError = nil } }
          )) { Button("general_ok") {} }
        }
    }

    /// After calculating, scroll so the scenarios sit at the top of the viewport.
    private func scrollToResults(_ proxy: ScrollViewProxy) {
        guard !scenarios.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { proxy.scrollTo("results", anchor: .top) }
        }
    }

    // MARK: - Results table

    private var scenariosTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(titleKey: "stress_scenarios_title", systemImage: "tablecells")
            VStack(spacing: 0) {
                HStack {
                    Text("stress_col_rate")   .frame(maxWidth: .infinity, alignment: .leading)
                    Text("stress_col_payment").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("stress_col_diff")   .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.bold()).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 6)

                Divider()

                ForEach(scenarios) { s in
                    HStack {
                        Text("\(s.delta >= 0 ? "+" : "")\(String(format: "%.1f", s.delta))%")
                            .foregroundStyle(rowColor(s.delta))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.payment.asCurrency(currencyCode))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(s.diff == 0 ? "—" : "\(s.diff > 0 ? "+" : "")\(s.diff.asCurrency(currencyCode))")
                            .foregroundStyle(rowColor(s.delta))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .padding(.horizontal).padding(.vertical, 10)
                    .background(s.delta == 0 ? Color.brandBlue.opacity(0.06) : Color.clear)

                    if s.id != scenarios.last?.id { Divider().padding(.leading) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Chart

    private var scenariosChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(titleKey: "stress_chart_title", systemImage: "chart.bar.fill")
            Chart(scenarios) { s in
                BarMark(
                    x: .value("Δ", "\(s.delta >= 0 ? "+" : "")\(String(format: "%.0f", s.delta))%"),
                    y: .value("€/mes", s.payment)
                )
                .foregroundStyle(barColor(s.delta))
                .annotation(position: .top) {
                    Text(s.payment.asCompactCurrency(currencyCode))
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: chartYRange)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self) {
                        AxisValueLabel { Text(d.asCompactCurrency(currencyCode)).font(.caption2) }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func calculate() {
        validationError = nil
        guard let capital = Double(capitalText.replacingOccurrences(of: ",", with: ".")), capital > 0 else {
            validationError = "error_invalid_capital"; return
        }
        let months = totalMonths
        guard months > 0 else {
            validationError = "error_invalid_years"; return
        }
        guard let rate = Double(rateText.replacingOccurrences(of: ",", with: ".")), rate > 0 else {
            validationError = "error_invalid_rate"; return
        }
        scenarios = FinancialCalculator.stressTestScenarios(capital: capital, months: months, baseRate: rate)
    }

    private func rowColor(_ delta: Double) -> Color {
        if delta < 0 { return .brandGreen }
        if delta == 0 { return .brandBlue }
        return delta <= 2 ? .brandOrange : .brandRed
    }

    private func barColor(_ delta: Double) -> Color { rowColor(delta).opacity(0.75) }

    private var chartYRange: ClosedRange<Double> {
        let payments = scenarios.map(\.payment)
        guard let lo = payments.min(), let hi = payments.max() else { return 0...1000 }
        let pad = (hi - lo) * 0.15
        return max(0, lo - pad)...hi + pad
    }
}

#Preview {
    NavigationStack { StressTestView() }
}
