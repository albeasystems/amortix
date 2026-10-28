import Charts
import SwiftUI

private struct EuriborPaymentBar: Identifiable {
    var id: Int
    var label: String
    var amount: Double
}

struct EuriborReviewView: View {
    @EnvironmentObject private var vm: EuriborViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 14) {

                AmountFieldCard(
                    labelKey:     "euribor_remaining_capital",
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
                    labelKey:    "euribor_spread",
                    systemImage: "plus.forwardslash.minus",
                    text:        $vm.spreadText,
                    range:       0...5,
                    step:        0.05,
                    accentColor: .brandBlue,
                    infoKey:     "input_spread"
                )

                RateSliderCard(
                    labelKey:    "euribor_current_rate",
                    systemImage: "waveform.path.ecg",
                    text:        $vm.currentEuriborText,
                    range:       -2...10,
                    step:        0.05,
                    accentColor: .brandOrange,
                    infoKey:     "input_euribor"
                )

                RateSliderCard(
                    labelKey:    "euribor_scenario_label",
                    systemImage: "arrow.up.arrow.down.circle",
                    text:        $vm.scenarioDeltaText,
                    range:       -3...5,
                    step:        0.05,
                    accentColor: .brandRed,
                    infoKey:     "input_euribor_delta"
                )

                // Calculate button
                Button {
                    HapticService.impact()
                    vm.calculateEuribor()
                    scrollToResults(proxy)
                } label: {
                    Text("calculator_btn_calculate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Scroll anchor — pressing Calculate jumps the view here
                Color.clear.frame(height: 0).id("results")

                // Results
                if vm.hasEuriborResult, let result = vm.euriborResult {
                    resultSection(result: result, code: vm.currencyCode)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

            }
            .padding(16)
            .adaptiveMaxWidth()
            .frame(maxWidth: .infinity)
          }
          .scrollDismissesKeyboard(.interactively)
          .animation(.spring(response: 0.35, dampingFraction: 1), value: vm.hasEuriborResult)
          .alert(vm.validationError ?? "error_invalid_capital", isPresented: Binding(
              get: { vm.validationError != nil },
              set: { if !$0 { vm.validationError = nil } }
          )) { Button("general_ok") {} }
        }
    }

    /// After a calculation, scroll so the results sit at the top of the viewport.
    private func scrollToResults(_ proxy: ScrollViewProxy) {
        guard vm.hasEuriborResult else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { proxy.scrollTo("results", anchor: .top) }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultSection(result: EuriborReviewResult, code: String) -> some View {
        VStack(spacing: 12) {
            if sizeClass == .regular {
                HStack(spacing: 12) {
                    ResultCard(labelKey: "euribor_current_payment",
                               value: result.currentPayment.asCurrency(code),
                               valueColor: .primary)
                    ResultCard(labelKey: "euribor_simulated_payment",
                               value: result.simulatedPayment.asCurrency(code),
                               valueColor: result.simulatedPayment > result.currentPayment ? .brandRed : .brandGreen,
                               isHighlighted: true)
                }
            } else {
                ResultCard(labelKey: "euribor_current_payment",
                           value: result.currentPayment.asCurrency(code),
                           valueColor: .primary)
                ResultCard(labelKey: "euribor_simulated_payment",
                           value: result.simulatedPayment.asCurrency(code),
                           valueColor: result.simulatedPayment > result.currentPayment ? .brandRed : .brandGreen,
                           isHighlighted: true)
            }

            ResultCard(labelKey: "euribor_difference_monthly",
                       value: result.monthlyDifference.currencyDifference(code: code),
                       valueColor: result.monthlyDifference > 0 ? .brandRed : .brandGreen,
                       infoKey: "euribor_diff_monthly",
                       infoScenario: KPIScenario(
                           code:              code,
                           currentPayment:    result.currentPayment,
                           simulatedPayment:  result.simulatedPayment,
                           monthlyDifference: result.monthlyDifference,
                           annualDifference:  result.annualDifference
                       ))
            ResultCard(labelKey: "euribor_difference_annual",
                       value: result.annualDifference.currencyDifference(code: code),
                       valueColor: result.annualDifference > 0 ? .brandRed : .brandGreen)

            paymentComparisonChart(result: result, code: code)
        }
    }

    // MARK: - Payment comparison chart

    private func paymentComparisonChart(result: EuriborReviewResult, code: String) -> some View {
        let isUp = result.simulatedPayment > result.currentPayment
        // Use raw localization keys as category values; resolve to localized
        // text via Text(LocalizedStringKey) in the Y-axis label so that the
        // SwiftUI environment locale (selectedLanguage AppStorage) is honored.
        let bars = [
            EuriborPaymentBar(id: 0,
                              label: "euribor_current_payment",
                              amount: result.currentPayment),
            EuriborPaymentBar(id: 1,
                              label: "euribor_simulated_payment",
                              amount: result.simulatedPayment)
        ]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.bold()).foregroundStyle(Color.brandBlue)
                Text("euribor_chart_title")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }
            Chart(bars) { bar in
                BarMark(
                    x: .value("", bar.amount),
                    y: .value("", bar.label)
                )
                .foregroundStyle(bar.id == 0 ? Color.brandBlue : (isUp ? Color.brandRed : Color.brandGreen))
                .annotation(position: .trailing, alignment: .leading) {
                    Text(bar.amount.asCurrency(code))
                        .font(.caption2.bold())
                        .foregroundStyle(bar.id == 0 ? Color.brandBlue : (isUp ? Color.brandRed : Color.brandGreen))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) { value in
                    AxisValueLabel {
                        if let key = value.as(String.self) {
                            Text(LocalizedStringKey(key)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 90)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack { EuriborReviewView().environmentObject(EuriborViewModel()) }
}
