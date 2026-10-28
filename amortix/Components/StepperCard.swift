import SwiftUI

/// Styled input card for integer values (years, months) — uses +/− buttons.
struct StepperCard: View {
    let labelKey:    LocalizedStringKey
    let systemImage: String
    @Binding var text: String
    let unitKey:     LocalizedStringKey
    var range:       ClosedRange<Int> = 1...50
    var step:        Int              = 1
    var accentColor: Color            = .brandOrange
    var infoKey:     String?          = nil
    var infoScenario: KPIScenario?    = nil

    @State private var showInfo = false

    private var value: Int {
        Int(text) ?? range.lowerBound
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                Text(labelKey)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
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

            // Controls
            HStack(alignment: .center, spacing: 0) {
                // Minus
                stepButton(systemName: "minus", action: decrement)
                    .opacity(value <= range.lowerBound ? 0.3 : 1)
                    .disabled(value <= range.lowerBound)

                Spacer()

                // Value + unit
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2, dampingFraction: 1), value: value)
                    Text(unitKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.lowercase)
                }

                Spacer()

                // Plus
                stepButton(systemName: "plus", action: increment, filled: true)
                    .opacity(value >= range.upperBound ? 0.3 : 1)
                    .disabled(value >= range.upperBound)
            }

            // Range hint bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 4)
                    Capsule()
                        .fill(accentColor.opacity(0.6))
                        .frame(width: progressWidth(geo.size.width), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
        .sheet(isPresented: $showInfo) {
            if let key = infoKey { KPIInfoView(infoKey: key, scenario: infoScenario) }
        }
    }

    // MARK: - Helpers

    private func stepButton(
        systemName: String,
        action: @escaping () -> Void,
        filled: Bool = false
    ) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3.bold())
                .frame(width: 52, height: 52)
                .background(filled ? accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(filled ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func decrement() {
        let newVal = max(range.lowerBound, value - step)
        text = "\(newVal)"
    }

    private func increment() {
        let newVal = min(range.upperBound, value + step)
        text = "\(newVal)"
    }

    private func progressWidth(_ total: CGFloat) -> CGFloat {
        let span   = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return total }
        let progress = Double(value - range.lowerBound) / span
        return total * CGFloat(progress.clamped(to: 0...1))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

#Preview {
    VStack(spacing: 12) {
        StepperCard(
            labelKey: "Duración del préstamo",
            systemImage: "calendar",
            text: .constant("25"),
            unitKey: "años",
            range: 1...40
        )
        StepperCard(
            labelKey: "Meses restantes",
            systemImage: "clock",
            text: .constant("180"),
            unitKey: "meses",
            range: 1...480,
            accentColor: .brandBlue
        )
    }
    .padding()
}
