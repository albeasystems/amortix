import SwiftUI

/// Styled input card for large monetary amounts.
/// Tapping anywhere opens a `NumericKeypadSheet`.
struct AmountFieldCard: View {
    let labelKey:     LocalizedStringKey
    let systemImage:  String
    @Binding var text: String
    let currencyCode: String
    var infoKey:      String? = nil
    var infoScenario: KPIScenario? = nil

    @State private var showKeypad = false
    @State private var showInfo   = false

    private var displayValue: String {
        let raw = text.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(raw), d > 0 else { return "–" }
        let hasDecimal = raw.contains(".")
        let fmt = NumberFormatter()
        fmt.numberStyle    = .decimal
        fmt.groupingSeparator = Locale.current.groupingSeparator ?? "."
        fmt.decimalSeparator  = Locale.current.decimalSeparator  ?? ","
        fmt.minimumFractionDigits = hasDecimal ? min(2, raw.components(separatedBy: ".").last?.count ?? 0) : 0
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: d)) ?? raw
    }

    var body: some View {
        Button { showKeypad = true } label: { cardBody }
            .buttonStyle(.plain)
            .sheet(isPresented: $showKeypad) {
                NumericKeypadSheet(labelKey: labelKey, symbolKey: currencyCode, text: $text)
            }
            .sheet(isPresented: $showInfo) {
                if let key = infoKey { KPIInfoView(infoKey: key, scenario: infoScenario) }
            }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(Color.brandBlue)
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

            // Value row
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currencyCode)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.brandBlue.opacity(0.10))
                    .foregroundStyle(Color.brandBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(displayValue)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(text.isEmpty ? Color(.placeholderText) : .primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        AmountFieldCard(
            labelKey: "Capital inicial",
            systemImage: "house.fill",
            text: .constant("150000"),
            currencyCode: "EUR",
            infoKey: "input_capital"
        )
        AmountFieldCard(
            labelKey: "Cantidad a amortizar",
            systemImage: "arrow.counterclockwise",
            text: .constant(""),
            currencyCode: "EUR"
        )
    }
    .padding()
}
