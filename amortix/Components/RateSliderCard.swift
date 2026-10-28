import SwiftUI

/// Styled input card for percentage rates — uses an inline slider.
struct RateSliderCard: View {
    let labelKey:    LocalizedStringKey
    let systemImage: String
    @Binding var text: String
    var range:       ClosedRange<Double> = 0.05...15.0
    var step:        Double              = 0.05
    var accentColor: Color               = .brandTeal
    var infoKey:     String?             = nil
    var infoScenario: KPIScenario?       = nil

    @State private var showInfo = false

    // MARK: - Binding bridge

    private var doubleValue: Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? range.lowerBound
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { doubleValue.clamped(to: range) },
            set: { text = String(format: "%.2f", $0) }
        )
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

            // Value display + fine-tune ±0.05 buttons  [−]  value  [+]
            HStack(alignment: .center, spacing: 0) {
                Button {
                    HapticService.selection()
                    let v = (doubleValue - step).rounded(toPlaces: 2)
                    sliderBinding.wrappedValue = v.clamped(to: range)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor.opacity(doubleValue <= range.lowerBound ? 0.3 : 1))
                }
                .buttonStyle(.plain)
                .disabled(doubleValue <= range.lowerBound)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.2f", doubleValue))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
                .animation(.spring(response: 0.2, dampingFraction: 1), value: doubleValue)

                Spacer()

                Button {
                    HapticService.selection()
                    let v = (doubleValue + step).rounded(toPlaces: 2)
                    sliderBinding.wrappedValue = v.clamped(to: range)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor.opacity(doubleValue >= range.upperBound ? 0.3 : 1))
                }
                .buttonStyle(.plain)
                .disabled(doubleValue >= range.upperBound)
            }

            // Slider
            Slider(value: sliderBinding, in: range, step: step)
                .tint(accentColor)

            // Min / Max labels
            HStack {
                Text(String(format: "%.0f%%", range.lowerBound))
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(String(format: "%.0f%%", range.upperBound))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
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
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

#Preview {
    VStack(spacing: 12) {
        RateSliderCard(
            labelKey: "Tipo de interés (TIN)",
            systemImage: "percent",
            text: .constant("3.50"),
            range: 0.05...15,
            step: 0.05
        )
        RateSliderCard(
            labelKey: "Euribor actual",
            systemImage: "waveform.path.ecg",
            text: .constant("3.75"),
            range: -2...10,
            step: 0.05,
            accentColor: .brandOrange
        )
    }
    .padding()
}
