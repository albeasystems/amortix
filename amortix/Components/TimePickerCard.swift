import SwiftUI

/// Compact card showing Years + Months columns side by side with ±1 buttons.
/// Replaces two full-width StepperCards that would overflow when placed in an HStack.
struct TimePickerCard: View {
    let labelKey:    LocalizedStringKey
    let systemImage: String
    @Binding var yearsText:  String
    @Binding var monthsText: String
    var maxYears:    Int    = 40
    var accentColor: Color  = .brandBlue
    var infoKey:     String? = nil

    @State private var showInfo = false

    private var years:  Int { Int(yearsText)  ?? 0 }
    private var months: Int { Int(monthsText) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.bold()).foregroundStyle(accentColor)
                Text(labelKey)
                    .font(.caption.bold()).textCase(.uppercase).tracking(0.7).foregroundStyle(.secondary)
                Spacer()
                if infoKey != nil {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandBlue.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Two columns: Years | Months
            HStack(spacing: 0) {
                column(
                    value: years,
                    unitKey: "general_years",
                    canDecrement: years > 0,
                    canIncrement: years < maxYears,
                    onDecrement: { yearsText = "\(max(0, years - 1))" },
                    onIncrement: { yearsText = "\(min(maxYears, years + 1))" }
                )

                Divider().frame(height: 64).padding(.horizontal, 8)

                column(
                    value: months,
                    unitKey: "general_months",
                    canDecrement: months > 0,
                    canIncrement: months < 11,
                    onDecrement: { monthsText = "\(max(0, months - 1))" },
                    onIncrement: { monthsText = "\(min(11, months + 1))" }
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))
        .sheet(isPresented: $showInfo) {
            if let key = infoKey { KPIInfoView(infoKey: key) }
        }
    }

    // MARK: - Column

    private func column(
        value: Int,
        unitKey: LocalizedStringKey,
        canDecrement: Bool,
        canIncrement: Bool,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                HapticService.selection()
                onDecrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canDecrement ? accentColor : Color(.tertiarySystemFill))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)

            VStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2, dampingFraction: 1), value: value)
                    .frame(minWidth: 36)
                Text(unitKey)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.lowercase)
            }

            Button {
                HapticService.selection()
                onIncrement()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canIncrement ? accentColor : Color(.tertiarySystemFill))
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TimePickerCard(
        labelKey: "Tiempo restante",
        systemImage: "calendar",
        yearsText: .constant("20"),
        monthsText: .constant("3")
    )
    .padding()
}
