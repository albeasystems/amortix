import Charts
import SwiftUI

struct ExtraPaymentsView: View {
    @EnvironmentObject private var vm: ExtraPaymentsViewModel
    @AppStorage("amortizationSystem") private var systemRaw = AmortizationSystem.french.rawValue
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var selectedSystem: AmortizationSystem {
        AmortizationSystem(rawValue: systemRaw) ?? .french
    }

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 14) {

                SystemBadge(system: selectedSystem)

                // MARK: Description card
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("extra_view_title")
                            .font(.subheadline.bold())
                        Text("extra_view_description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                AmountFieldCard(
                    labelKey:     "partial_remaining_capital",
                    systemImage:  "house.fill",
                    text:         $vm.remainingCapitalText,
                    currencyCode: vm.currencyCode,
                    infoKey:      "input_remaining_capital"
                )

                TimePickerCard(
                    labelKey:    "partial_time_remaining",
                    systemImage: "calendar",
                    yearsText:   $vm.remainingYearsText,
                    monthsText:  $vm.remainingExtraMonthsText,
                    accentColor: .brandBlue,
                    infoKey:     "input_months"
                )

                RateSliderCard(
                    labelKey:    "partial_current_rate",
                    systemImage: "percent",
                    text:        $vm.currentRateText,
                    range:       0.05...15,
                    step:        0.05,
                    infoKey:     "input_rate"
                )

                AmountFieldCard(
                    labelKey:     "extra_monthly_amount",
                    systemImage:  "plus.circle.fill",
                    text:         $vm.extraMonthlyText,
                    currencyCode: vm.currencyCode,
                    infoKey:      "input_extra_monthly"
                )

                // Simulate button
                Button {
                    HapticService.impact()
                    vm.simulate()
                    scrollToResults(proxy)
                } label: {
                    Text("extra_btn_simulate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Scroll anchor — pressing Simulate jumps the view here
                Color.clear.frame(height: 0).id("results")

                // Results
                if vm.hasResult, let result = vm.result {
                    resultsSection(result: result)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

            }
            .padding(16)
            .adaptiveMaxWidth()
            .frame(maxWidth: .infinity)
          }
          .scrollDismissesKeyboard(.interactively)
          .animation(.spring(response: 0.35, dampingFraction: 1), value: vm.hasResult)
          .alert(vm.validationError ?? "error_invalid_capital", isPresented: Binding(
              get: { vm.validationError != nil },
              set: { if !$0 { vm.validationError = nil } }
          )) { Button("general_ok") {} }
        }
    }

    /// After a simulation, scroll so the results sit at the top of the viewport.
    private func scrollToResults(_ proxy: ScrollViewProxy) {
        guard vm.hasResult else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { proxy.scrollTo("results", anchor: .top) }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsSection(result: ExtraPaymentsResult) -> some View {
        let code = vm.currencyCode
        let scenario = KPIScenario(
            code:           code,
            monthsSaved:    result.monthsSaved,
            interestSaved:  result.interestSaved,
            newPayment:     result.currentPayment,
            currentPayment: result.currentPayment
        )
        VStack(spacing: 12) {
            if sizeClass == .regular {
                HStack(spacing: 12) {
                    ResultCard(labelKey: "extra_months_saved",
                               value: "\(result.monthsSaved)",
                               valueColor: .brandGreen,
                               isHighlighted: true,
                               infoKey: "months_saved",
                               infoScenario: scenario)
                    ResultCard(labelKey: "extra_interest_saved",
                               value: result.interestSaved.asCurrency(code),
                               valueColor: .brandTeal,
                               isHighlighted: true,
                               infoKey: "interest_saved",
                               infoScenario: scenario)
                }
                HStack(spacing: 12) {
                    ResultCard(labelKey: "extra_current_payment",
                               value: result.currentPayment.asCurrency(code),
                               valueColor: .primary)
                    ResultCard(labelKey: "extra_new_payoff",
                               value: monthsLabel(result.newPayoffMonths),
                               valueColor: .brandBlue)
                }
            } else {
                ResultCard(labelKey: "extra_months_saved",
                           value: "\(result.monthsSaved)",
                           valueColor: .brandGreen,
                           isHighlighted: true,
                           infoKey: "months_saved",
                           infoScenario: scenario)
                ResultCard(labelKey: "extra_interest_saved",
                           value: result.interestSaved.asCurrency(code),
                           valueColor: .brandTeal,
                           isHighlighted: true,
                           infoKey: "interest_saved",
                           infoScenario: scenario)
                ResultCard(labelKey: "extra_current_payment",
                           value: result.currentPayment.asCurrency(code),
                           valueColor: .primary)
                ResultCard(labelKey: "extra_new_payoff",
                           value: monthsLabel(result.newPayoffMonths),
                           valueColor: .brandBlue)
            }

            interestComparisonChart(result: result, code: code)

            if !result.schedule.isEmpty {
                balanceChart(rows: result.schedule, code: code)
            }
        }
    }

    // MARK: - Charts

    private func interestComparisonChart(result: ExtraPaymentsResult, code: String) -> some View {
        let data: [(String, Double)] = [
            ("extra_without_extra", result.totalInterestWithout),
            ("extra_with_extra",    result.totalInterestWithExtra),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(titleKey: "extra_interest_comparison")
            Chart(data, id: \.0) { item in
                BarMark(x: .value("€", item.1), y: .value("T", item.0))
                    .foregroundStyle(item.0.contains("without") ? Color.brandOrange.opacity(0.7) : Color.brandGreen.opacity(0.7))
                    .annotation(position: .trailing) {
                        Text(item.1.asCompactCurrency(code)).font(.caption2)
                    }
            }
            .frame(height: 80)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) { value in
                    AxisValueLabel {
                        if let key = value.as(String.self) {
                            Text(LocalizedStringKey(key))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func balanceChart(rows: [ExtraPaymentsRow], code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(titleKey: "extra_balance_chart", systemImage: "chart.line.downtrend.xyaxis")
            Chart {
                ForEach(rows) { row in
                    AreaMark(x: .value("P", row.id), yStart: .value("I0", 0), yEnd: .value("I", row.interest))
                        .foregroundStyle(Color.brandOrange.opacity(0.4))
                    LineMark(x: .value("P", row.id), y: .value("B", row.balance))
                        .foregroundStyle(Color.brandBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self) {
                        AxisValueLabel { Text(d.asCompactCurrency(code)).font(.caption2) }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func monthsLabel(_ months: Int) -> String {
        let y = months / 12; let m = months % 12
        if y > 0 && m > 0 { return "\(y)a \(m)m" }
        if y > 0 { return "\(y)a" }
        return "\(m)m"
    }
}

#Preview {
    NavigationStack {
        ExtraPaymentsView().environmentObject(ExtraPaymentsViewModel())
    }
}
