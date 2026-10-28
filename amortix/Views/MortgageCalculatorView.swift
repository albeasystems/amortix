import SwiftUI

struct MortgageCalculatorView: View {
    @EnvironmentObject private var vm: MortgageViewModel
    @AppStorage("amortizationSystem") private var systemRaw = AmortizationSystem.french.rawValue
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var selectedSystem: AmortizationSystem {
        AmortizationSystem(rawValue: systemRaw) ?? .french
    }

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 14) {

                // System in use (hidden for mixed, which ignores it — it runs a
                // two-phase French schedule explained in its own result card).
                if vm.mortgageType != .mixed {
                    SystemBadge(system: selectedSystem)
                }

                // MARK: Capital
                AmountFieldCard(
                    labelKey:     "calculator_capital",
                    systemImage:  "house.fill",
                    text:         $vm.capitalText,
                    currencyCode: vm.currencyCode,
                    infoKey:      "input_capital",
                    infoScenario: inputScenario
                )

                // MARK: Years (always visible)
                StepperCard(
                    labelKey:     "calculator_years",
                    systemImage:  "calendar",
                    text:         $vm.yearsText,
                    unitKey:      "general_years",
                    range:        1...40,
                    infoKey:      "input_years",
                    infoScenario: inputScenario
                )

                // MARK: Mortgage type selector
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption.bold()).foregroundStyle(Color.brandBlue)
                        Text("calculator_section_type")
                            .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
                    }
                    Picker("", selection: $vm.mortgageType) {
                        ForEach(MortgageType.allCases) { t in
                            Text(LocalizedStringKey(t.localizedKey)).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))

                // MARK: Rate fields — depend on mortgage type
                //
                // Fixed:    TIN only
                // Variable: reference rate + spread (TIN not used)
                // Mixed:    TIN (fixed phase) + fixed period years + reference rate + spread (variable phase)

                if vm.mortgageType == .fixed || vm.mortgageType == .mixed {
                    RateSliderCard(
                        labelKey:     vm.mortgageType == .mixed ? "calculator_tin_mixed" : "calculator_tin",
                        systemImage:  "percent",
                        text:         $vm.tinText,
                        range:        0.05...15,
                        step:         0.05,
                        infoKey:      "input_rate",
                        infoScenario: inputScenario
                    )
                }

                if vm.mortgageType == .mixed {
                    StepperCard(
                        labelKey:    "calculator_fixed_period_years",
                        systemImage: "lock.shield",
                        text:        $vm.fixedPeriodYearsText,
                        unitKey:     "general_years",
                        range:       1...20,
                        accentColor: .brandBlue
                    )
                }

                if vm.mortgageType == .variable || vm.mortgageType == .mixed {
                    RateSliderCard(
                        labelKey:    "calculator_reference_rate",
                        systemImage: "waveform.path.ecg",
                        text:        $vm.euriborText,
                        range:       -2...10,
                        step:        0.05,
                        accentColor: .brandOrange,
                        infoKey:     "input_euribor"
                    )
                    RateSliderCard(
                        labelKey:    "calculator_spread",
                        systemImage: "plus.forwardslash.minus",
                        text:        $vm.spreadText,
                        range:       0...5,
                        step:        0.05,
                        accentColor: .brandBlue,
                        infoKey:     "input_spread"
                    )

                    // For mixed: show the effective variable rate as a read-only hint
                    if vm.mortgageType == .mixed {
                        effectiveRateHint(euriborText: vm.euriborText, spreadText: vm.spreadText)
                    }
                }

                // Scroll anchor — pressing Calculate jumps the view here
                Color.clear.frame(height: 0).id("results")

                // MARK: Results
                if vm.hasResult, let result = vm.result {
                    resultSection(result: result, code: vm.currencyCode)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

            }
            .padding(16)
            .adaptiveMaxWidth()
            .frame(maxWidth: .infinity)
          }
          .scrollDismissesKeyboard(.interactively)
          // Pinned above the ad stack (MainTabView's bottom inset) so the banner
          // can never cover it, whatever the screen height.
          .safeAreaInset(edge: .bottom, spacing: 0) {
              calculateButton {
                  vm.system = selectedSystem
                  vm.calculate()
                  scrollToResults(proxy)
              }
              .padding(.horizontal, 16)
              .padding(.top, 8)
              .padding(.bottom, 8)
              .background(Color(.systemGroupedBackground))
          }
          .animation(.spring(response: 0.35, dampingFraction: 1), value: vm.hasResult)
          .animation(.spring(response: 0.25, dampingFraction: 1), value: vm.mortgageType)
          // Clear result when switching mortgage type — would show stale data
          .onChange(of: vm.mortgageType) { _ in vm.clearResult() }
          .onAppear { vm.system = selectedSystem }
          // Keep the calculator in sync with the system chosen in Settings.
          .onChange(of: systemRaw) { _ in
              vm.system = selectedSystem
              if vm.hasResult { vm.calculate() }
          }
          .alert(vm.validationError ?? "error_invalid_capital", isPresented: Binding(
              get: { vm.validationError != nil },
              set: { if !$0 { vm.validationError = nil } }
          )) { Button("general_ok") {} }
        }
    }

    /// After a calculation, scroll so the results sit at the top of the viewport.
    private func scrollToResults(_ proxy: ScrollViewProxy) {
        guard vm.hasResult else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { proxy.scrollTo("results", anchor: .top) }
        }
    }

    // MARK: - Effective rate hint (mixed only)

    private func effectiveRateHint(euriborText: String, spreadText: String) -> some View {
        let euribor = Double(euriborText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let spread  = Double(spreadText.replacingOccurrences(of: ",", with: "."))  ?? 0
        let effective = FinancialCalculator.variableRate(euribor: euribor, spread: spread)
        return HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.brandBlue)
            // key: "calculator_mixed_effective_hint %@" — % is embedded in the formatted string
            Text("calculator_mixed_effective_hint \(String(format: "%.2f%%", effective))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Calculate button

    private func calculateButton(_ action: @escaping () -> Void) -> some View {
        Button {
            HapticService.impact()
            action()
        } label: {
            Text("calculator_btn_calculate")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandBlue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Results

    /// Clarifies the headline instalment for non-constant systems: Linear shows
    /// the (highest) first instalment; American shows the interest-only payment.
    private func paymentSubtitle(for system: AmortizationSystem) -> LocalizedStringKey? {
        switch system {
        case .french:   return nil
        case .linear:   return "calculator_payment_first"
        case .american: return "calculator_payment_interest_only"
        }
    }

    @ViewBuilder
    private func resultSection(result: MortgageResult, code: String) -> some View {
        let scenario = makeScenario(result: result, code: code)
        VStack(spacing: 12) {

            if result.mortgageType == .mixed {
                mixedPaymentCards(result: result, code: code, scenario: scenario)
                mixedExplanationCard(result: result, code: code)
            } else {
                ResultCard(
                    labelKey:      "calculator_result_monthly",
                    value:         result.monthlyPayment.asCurrency(code),
                    valueColor:    .brandBlue,
                    isHighlighted: true,
                    systemImage:   "creditcard",
                    subtitle:      paymentSubtitle(for: result.system),
                    infoKey:       "monthly_payment",
                    infoScenario:  scenario
                )
            }

            if sizeClass == .regular {
                HStack(spacing: 12) {
                    ResultCard(labelKey: "calculator_result_total_interest",
                               value: result.totalInterest.asCurrency(code),
                               valueColor: .brandOrange,
                               systemImage: "chart.line.uptrend.xyaxis",
                               infoKey: "total_interest",
                               infoScenario: scenario)
                    ResultCard(labelKey: "calculator_result_total_cost",
                               value: result.totalCost.asCurrency(code),
                               valueColor: .primary,
                               systemImage: "sum",
                               infoKey: "total_cost",
                               infoScenario: scenario)
                }
            } else {
                ResultCard(labelKey: "calculator_result_total_interest",
                           value: result.totalInterest.asCurrency(code),
                           valueColor: .brandOrange,
                           systemImage: "chart.line.uptrend.xyaxis",
                           infoKey: "total_interest",
                           infoScenario: scenario)
                ResultCard(labelKey: "calculator_result_total_cost",
                           value: result.totalCost.asCurrency(code),
                           valueColor: .primary,
                           systemImage: "sum",
                           infoKey: "total_cost",
                           infoScenario: scenario)
            }

            // American: the principal is repaid in full as a final bullet —
            // surface it so the interest-only headline isn't misleading.
            if result.mortgageType != .mixed, result.system == .american {
                ResultCard(labelKey: "calculator_result_final_capital",
                           value: (result.amortizationTable.last?.principal ?? 0).asCurrency(code),
                           valueColor: .brandBlue,
                           systemImage: "flag.checkered")
            }

            // Capital vs interest breakdown chart
            CapitalInterestChartView(rows: result.amortizationTable, code: code)

            NavigationLink {
                AmortizationTableView(result: result)
            } label: {
                Label("calculator_btn_see_table", systemImage: "tablecells")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(Color.brandBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Mixed mortgage cards

    @ViewBuilder
    private func mixedPaymentCards(result: MortgageResult, code: String, scenario: KPIScenario) -> some View {
        VStack(spacing: 12) {
            ResultCard(
                labelKey:      "calculator_result_mixed_fixed",
                value:         (result.fixedPhasePayment ?? result.monthlyPayment).asCurrency(code),
                valueColor:    .brandBlue,
                isHighlighted: true,
                infoKey:       "mixed_fixed_payment",
                infoScenario:  scenario
            )
            ResultCard(
                labelKey:      "calculator_result_mixed_variable",
                value:         (result.variablePhasePayment ?? 0).asCurrency(code),
                valueColor:    .brandOrange,
                isHighlighted: true,
                infoKey:       "mixed_variable_payment",
                infoScenario:  scenario
            )
        }
    }

    private func mixedExplanationCard(result: MortgageResult, code: String) -> some View {
        let fixedYears  = (result.fixedPhaseMonths ?? 0) / 12
        let fixedPmt    = (result.fixedPhasePayment ?? result.monthlyPayment).asCurrency(code)
        let tin         = (Double(vm.tinText.replacingOccurrences(of: ",", with: ".")) ?? 0).asPercentage
        let varRate     = (result.variableRate ?? 0).asPercentage
        let varPmt      = (result.variablePhasePayment ?? 0).asCurrency(code)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").foregroundStyle(Color.brandBlue)
                Text("calculator_mixed_explanation_title")
                    .font(.subheadline.bold())
            }
            Divider()
            Text("\(Text("calculator_mixed_explain_s1a")) \(Text("\(fixedYears)").bold()) \(Text("calculator_mixed_explain_s1b")) \(Text(fixedPmt).bold()) \(Text("calculator_mixed_explain_s1c")) \(Text(tin).bold()).")
                .font(.subheadline)
            Text("\(Text("calculator_mixed_explain_s2a")) \(Text(varRate).bold()) \(Text("calculator_mixed_explain_s2b")) \(Text(varPmt).bold()).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.brandBlue.opacity(0.3), lineWidth: 1))
    }

    // MARK: - KPI scenario (real numbers for the ⓘ sheet)

    /// Scenario built from the *current inputs* (capital, years, rate) so the input
    /// field ⓘ sheets (capital / años / TIN) show "Con tus números" live, even
    /// before pressing Calculate. Folds in the computed result when one exists.
    private var inputScenario: KPIScenario {
        let capital = Double(vm.capitalText.replacingOccurrences(of: ",", with: "."))
            .flatMap { $0 > 0 ? $0 : nil }
        let years = Int(vm.yearsText).flatMap { $0 > 0 ? $0 : nil }
        let rate: Double? = {
            switch vm.mortgageType {
            case .fixed, .mixed:
                return Double(vm.tinText.replacingOccurrences(of: ",", with: "."))
            case .variable:
                let e = Double(vm.euriborText.replacingOccurrences(of: ",", with: ".")) ?? 0
                let s = Double(vm.spreadText.replacingOccurrences(of: ",", with: ".")) ?? 0
                return FinancialCalculator.variableRate(euribor: e, spread: s)
            }
        }()

        var scenario = KPIScenario(code: vm.currencyCode, capital: capital, years: years, rate: rate)

        if let result = vm.result {
            scenario.monthlyPayment      = result.monthlyPayment
            scenario.totalInterest       = result.totalInterest
            scenario.totalCost           = result.totalCost
            scenario.firstMonthInterest  = result.amortizationTable.first?.interest
            scenario.firstMonthPrincipal = result.amortizationTable.first?.principal
        }
        return scenario
    }

    private func makeScenario(result: MortgageResult, code: String) -> KPIScenario {
        let capital = result.totalCost - result.totalInterest
        let first   = result.amortizationTable.first
        let years   = max(1, result.amortizationTable.count / 12)
        let effectiveRate: Double = {
            switch result.mortgageType {
            case .fixed, .mixed:
                return Double(vm.tinText.replacingOccurrences(of: ",", with: ".")) ?? 0
            case .variable:
                let e = Double(vm.euriborText.replacingOccurrences(of: ",", with: ".")) ?? 0
                let s = Double(vm.spreadText.replacingOccurrences(of: ",", with: ".")) ?? 0
                return FinancialCalculator.variableRate(euribor: e, spread: s)
            }
        }()
        return KPIScenario(
            code:                code,
            capital:             capital,
            years:               years,
            rate:                effectiveRate,
            monthlyPayment:      result.monthlyPayment,
            totalInterest:       result.totalInterest,
            totalCost:           result.totalCost,
            firstMonthInterest:  first?.interest,
            firstMonthPrincipal: first?.principal,
            fixedYears:          result.fixedPhaseMonths.map { $0 / 12 },
            fixedPayment:        result.fixedPhasePayment,
            balanceAfterFixed:   result.balanceAfterFixed,
            variableRate:        result.variableRate,
            variablePayment:     result.variablePhasePayment
        )
    }
}

#Preview {
    NavigationStack {
        MortgageCalculatorView().environmentObject(MortgageViewModel())
    }
}
