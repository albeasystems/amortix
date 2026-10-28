import Charts
import SwiftUI

struct PartialAmortizationView: View {
    @EnvironmentObject private var vm: PartialAmortizationViewModel
    @AppStorage("amortizationSystem") private var systemRaw = AmortizationSystem.french.rawValue

    @State private var selectedTab: ResultTab = .reducePayment

    enum ResultTab { case reducePayment, reduceTerm }

    private var selectedSystem: AmortizationSystem {
        AmortizationSystem(rawValue: systemRaw) ?? .french
    }

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 14) {

                SystemBadge(system: selectedSystem)

                // MARK: Inputs
                AmountFieldCard(
                    labelKey:     "partial_remaining_capital",
                    systemImage:  "house.fill",
                    text:         $vm.remainingCapitalText,
                    currencyCode: vm.currencyCode,
                    infoKey:      "input_remaining_capital"
                )

                // Compact years + extra months in a single card
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
                    labelKey:     "partial_amount",
                    systemImage:  "arrow.counterclockwise",
                    text:         $vm.amountToAmortizeText,
                    currencyCode: vm.currencyCode,
                    infoKey:      "input_amortize_amount"
                )

                // MARK: Commission (mortgage type only visible when auto)
                commissionSection()

                // MARK: Calculate button
                Button {
                    HapticService.impact()
                    vm.simulate()
                    scrollToResults(proxy)
                } label: {
                    Text("partial_btn_simulate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Scroll anchor — pressing Simulate jumps the view here
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
          .animation(.spring(response: 0.35, dampingFraction: 1), value: vm.hasResult)
          .animation(.easeInOut(duration: 0.2), value: selectedTab)
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

    // MARK: - Commission Section

    @ViewBuilder
    private func commissionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "banknote.fill")
                    .font(.caption.bold()).foregroundStyle(Color.brandRed)
                Text("partial_section_commission")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }

            Picker("", selection: $vm.commissionMode) {
                ForEach(CommissionMode.allCases) { m in
                    Text(LocalizedStringKey(m.localizedKey)).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if vm.commissionMode == .auto {
                VStack(alignment: .leading, spacing: 6) {
                    Text("partial_mortgage_type")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $vm.mortgageType) {
                        ForEach(MortgageType.allCases) { t in
                            Text(LocalizedStringKey(t.localizedKey)).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                StepperCard(
                    labelKey:    "partial_years_since_signing",
                    systemImage: "calendar.badge.clock",
                    text:        $vm.yearsSinceSigningText,
                    unitKey:     "general_years",
                    range:       0...30,
                    accentColor: .brandRed
                )
                Text(vm.commissionInfoKey)
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if vm.commissionMode == .percent {
                RateSliderCard(
                    labelKey:    "partial_commission_mode_percent",
                    systemImage: "percent",
                    text:        $vm.customCommissionPercentText,
                    range:       0...5, step: 0.05, accentColor: .brandRed
                )
            }
            if vm.commissionMode == .fixed {
                AmountFieldCard(
                    labelKey:     "partial_commission_mode_fixed",
                    systemImage:  "banknote",
                    text:         $vm.customCommissionFixedText,
                    currencyCode: vm.currencyCode
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))
    }

    // MARK: - Results Section

    @ViewBuilder
    private func resultSection(result: PartialAmortizationResult, code: String) -> some View {
        VStack(spacing: 14) {

            // Narrative explanation card
            narrativeCard(result: result, code: code)

            // Tab selector
            resultTabSelector(result: result)

            // Tab content
            let option = selectedTab == .reducePayment ? result.reducePayment : result.reduceTerm
            tabContent(option: option, tab: selectedTab, code: code,
                       originalMonths: result.originalMonths,
                       amountAmortized: result.amountAmortized)
        }
    }

    // MARK: - Narrative Card

    private func narrativeCard(result: PartialAmortizationResult, code: String) -> some View {
        let reduceP = result.reducePayment
        let reduceT = result.reduceTerm
        let best    = result.recommended == .reduceTerm ? reduceT : reduceP
        let worst   = result.recommended == .reduceTerm ? reduceP : reduceT
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.document.fill")
                    .foregroundStyle(Color.brandTeal)
                Text("partial_narrative_title")
                    .font(.subheadline.bold())
            }
            Divider()
            Group {
                // Sentence 1: capital reduction
                Text("\(Text("partial_narrative_s1a")) \(Text(result.amountAmortized.asCurrency(code)).bold()) \(Text("partial_narrative_s1b")) \(Text(result.newCapital.asCurrency(code)).bold()).")
                    .font(.subheadline)

                // Sentence 2: options
                Text("partial_narrative_s2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Sentence 3: savings comparison
                Text("\(Text("partial_narrative_s3a")) \(Text(worst.interestSaved.asCurrency(code)).bold()) \(Text("partial_narrative_s3b")) \(Text(best.interestSaved.asCurrency(code)).bold()).")
                    .font(.subheadline)

                // Sentence 4: commission (only if any)
                if result.commission > 0 {
                    Text("\(Text("partial_narrative_s4a")) \(Text(result.commission.asCurrency(code)).bold()) \(Text("partial_narrative_s4b"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.brandTeal.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Tab Selector

    private func resultTabSelector(result: PartialAmortizationResult) -> some View {
        HStack(spacing: 0) {
            tabButton(
                title: "partial_tab_reduce_payment",
                tab: .reducePayment,
                isRecommended: result.recommended == .reducePayment
            )
            tabButton(
                title: "partial_tab_reduce_term",
                tab: .reduceTerm,
                isRecommended: result.recommended == .reduceTerm
            )
        }
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))
    }

    private func tabButton(title: LocalizedStringKey, tab: ResultTab, isRecommended: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                if isRecommended {
                    Text("partial_recommended")
                        .font(.caption2.bold())
                        .foregroundStyle(selectedTab == tab ? .white.opacity(0.85) : Color.brandTeal)
                }
            }
            .padding(.vertical, 12)
            .background(selectedTab == tab ? Color.brandTeal : Color.clear)
            .foregroundStyle(selectedTab == tab ? .white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    private func tabContent(
        option: PartialAmortizationOption,
        tab: ResultTab,
        code: String,
        originalMonths: Int,
        amountAmortized: Double
    ) -> some View {
        let scenario = KPIScenario(
            code:            code,
            amountAmortized: amountAmortized,
            monthsSaved:     option.monthsSaved,
            interestSaved:   option.interestSaved,
            commission:      option.commissionCost,
            netSaving:       option.netSaving,
            newPayment:      option.newPayment,
            originalPayment: option.originalPayment
        )
        return VStack(spacing: 12) {

            // KPI summary cards
            if tab == .reducePayment {
                HStack(spacing: 12) {
                    kpiCard(
                        icon: "banknote",
                        titleKey: "partial_new_payment",
                        value: option.newPayment.asCurrency(code),
                        subValue: "← \(option.originalPayment.asCurrency(code))",
                        color: .brandBlue
                    )
                    kpiCard(
                        icon: "eurosign.circle",
                        titleKey: "partial_remaining_interest",
                        value: option.interestSaved.asCurrency(code),
                        color: .brandOrange
                    )
                }
                // Inline explanation
                Text("\(Text("partial_reduce_payment_explain_a")) \(Text(option.newPayment.asCurrency(code)).bold()) \(Text("partial_reduce_payment_explain_b")) \(Text(option.originalPayment.asCurrency(code)).bold()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                Text("\(Text("partial_saving_explain")) \(Text(option.netSaving.asCurrency(code)).bold()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                HStack(spacing: 12) {
                    kpiCard(
                        icon: "clock.badge.checkmark",
                        titleKey: "partial_new_term",
                        value: PartialAmortizationViewModel.termLabel(months: option.newTermMonths),
                        subValue: "← \(PartialAmortizationViewModel.termLabel(months: originalMonths))",
                        color: .brandBlue
                    )
                    kpiCard(
                        icon: "eurosign.circle",
                        titleKey: "partial_remaining_interest",
                        value: option.interestSaved.asCurrency(code),
                        color: .brandOrange
                    )
                }
                // Inline explanation
                Text("\(Text("partial_reduce_term_explain_a")) \(Text(PartialAmortizationViewModel.termLabel(months: option.newTermMonths)).bold()) \(Text("partial_reduce_term_explain_b")) \(Text(PartialAmortizationViewModel.termLabel(months: originalMonths)).bold()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                Text("\(Text("partial_saving_explain")) \(Text(option.netSaving.asCurrency(code)).bold()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            // Net saving + commission
            HStack(spacing: 12) {
                if option.commissionCost > 0 {
                    ResultCard(labelKey: "partial_commission_cost",
                               value: option.commissionCost.asCurrency(code),
                               valueColor: .brandRed, infoKey: "commission",
                               infoScenario: scenario)
                }
                ResultCard(labelKey: "partial_net_saving",
                           value: option.netSaving.asCurrency(code),
                           valueColor: option.netSaving >= 0 ? .brandGreen : .brandRed,
                           isHighlighted: true, infoKey: "net_saving",
                           infoScenario: scenario)
            }

            // Annual amortization table
            annualTable(schedule: option.schedule, code: code)

            // Charts
            paymentsChart(schedule: option.schedule, code: code)
            amortizationChart(schedule: option.schedule, code: code)
        }
    }

    // MARK: - KPI Card

    private func kpiCard(
        icon: String,
        titleKey: LocalizedStringKey,
        value: String,
        subValue: String? = nil,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(titleKey).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            if let sub = subValue {
                Text(sub).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Annual Table

    private func annualTable(schedule: [PartialAmortizationYearRow], code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "tablecells")
                    .font(.caption.bold()).foregroundStyle(Color.brandBlue)
                Text("partial_table_title")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // Header row
            tableRow(
                col1: Text("partial_table_year").font(.caption.bold()).foregroundColor(.secondary),
                col2: Text("partial_table_payment").font(.caption.bold()).foregroundColor(.secondary),
                col3: Text("partial_table_capital").font(.caption.bold()).foregroundColor(.secondary),
                col4: Text("partial_table_interest").font(.caption.bold()).foregroundColor(.secondary),
                col5: Text("partial_table_balance").font(.caption.bold()).foregroundColor(.secondary),
                isHeader: true
            )

            ForEach(schedule) { row in
                tableRow(
                    col1: Text("\(row.id)").font(.caption).foregroundColor(.primary),
                    col2: Text(row.payment.asCompactCurrency(code)).font(.caption2).foregroundColor(.primary),
                    col3: Text(row.capital.asCompactCurrency(code)).font(.caption2).foregroundColor(Color.brandBlue),
                    col4: Text(row.interest.asCompactCurrency(code)).font(.caption2).foregroundColor(Color.brandOrange),
                    col5: Text(row.balance.asCompactCurrency(code)).font(.caption2).foregroundColor(.secondary),
                    isHeader: false
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tableRow(
        col1: Text, col2: Text, col3: Text, col4: Text, col5: Text,
        isHeader: Bool
    ) -> some View {
        HStack(spacing: 0) {
            col1.frame(width: 28, alignment: .leading)
            col2.frame(maxWidth: .infinity, alignment: .trailing)
            col3.frame(maxWidth: .infinity, alignment: .trailing)
            col4.frame(maxWidth: .infinity, alignment: .trailing)
            col5.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHeader ? Color(.systemGroupedBackground) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator).opacity(0.4)),
            alignment: .bottom
        )
    }

    // MARK: - Payments Chart (stacked bar: capital + interest per year)

    private func paymentsChart(schedule: [PartialAmortizationYearRow], code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.bold()).foregroundStyle(Color.brandBlue)
                Text("partial_chart_payments_title")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(schedule) { row in
                    BarMark(x: .value("Año", row.id), y: .value("Capital", row.capital))
                        .foregroundStyle(by: .value("Tipo", "partial_chart_legend_capital"))
                    BarMark(x: .value("Año", row.id), y: .value("Intereses", row.interest))
                        .foregroundStyle(by: .value("Tipo", "partial_chart_legend_interest"))
                }
            }
            .chartForegroundStyleScale([
                "partial_chart_legend_capital":  Color.brandBlue,
                "partial_chart_legend_interest": Color.brandOrange.opacity(0.75)
            ])
            .chartLegend(position: .bottom, alignment: .leading) {
                legendRow(capitalColor: .brandBlue, interestColor: .brandOrange.opacity(0.75))
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
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func legendRow(capitalColor: Color, interestColor: Color) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Circle().fill(capitalColor).frame(width: 8, height: 8)
                Text("partial_chart_legend_capital").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(interestColor).frame(width: 8, height: 8)
                Text("partial_chart_legend_interest").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Amortization Chart (cumulative balance + interest area)

    private func amortizationChart(schedule: [PartialAmortizationYearRow], code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.caption.bold()).foregroundStyle(Color.brandTeal)
                Text("partial_chart_amort_title")
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(schedule) { row in
                    BarMark(x: .value("Año", row.id), y: .value("Capital", row.capital))
                        .foregroundStyle(by: .value("Tipo", "partial_chart_legend_capital"))
                    BarMark(x: .value("Año", row.id), y: .value("Intereses", row.interest))
                        .foregroundStyle(by: .value("Tipo", "partial_chart_legend_interest"))
                }
            }
            .chartForegroundStyleScale([
                "partial_chart_legend_capital":  Color.brandTeal,
                "partial_chart_legend_interest": Color.brandOrange.opacity(0.6)
            ])
            .chartLegend(position: .bottom, alignment: .leading) {
                legendRow(capitalColor: .brandTeal, interestColor: .brandOrange.opacity(0.6))
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
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        PartialAmortizationView().environmentObject(PartialAmortizationViewModel())
    }
}
