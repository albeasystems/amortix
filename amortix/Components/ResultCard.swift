import SwiftUI

struct ResultCard: View {
    let labelKey:      LocalizedStringKey
    let value:         String
    var valueColor:    Color  = .primary
    var isHighlighted: Bool   = false
    var systemImage:   String? = nil   // Optional leading icon (tinted with valueColor)
    var subtitle:      LocalizedStringKey? = nil   // Optional small caption under the value
    var infoKey:       String? = nil   // Pass a KPIInfo key to show the ⓘ button
    var infoScenario:  KPIScenario? = nil   // Real numbers for the "Con tus números" section

    @State private var showInfo = false

    // Secondary KPIs are 15% smaller than the headline so the highlighted
    // figure (e.g. the monthly payment) stands out — matches Capital's hierarchy.
    private var valueFont: Font {
        isHighlighted
            ? .title2.bold().monospacedDigit()
            : .system(size: 14.5, weight: .semibold).monospacedDigit()  // .headline (17) × 0.85
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(valueColor)
                }
                Text(labelKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if infoKey != nil {
                    Button {
                        HapticService.selection()
                        // Reading the breakdown of your own figures is real
                        // engagement, so it counts towards the escape valve and
                        // the interstitial pacing — but it never shows an ad or a
                        // rating prompt on top of the sheet the user just opened.
                        ReviewManager.shared.registerSecondaryAction()
                        AdsManager.shared.registerSecondaryAction()
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.brandBlue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isHighlighted
                ? valueColor.opacity(0.1)
                : Color(.secondarySystemGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .sheet(isPresented: $showInfo) {
            if let key = infoKey {
                KPIInfoView(infoKey: key, scenario: infoScenario)
            }
        }
    }
}

/// Small capsule badge showing which amortization system the calculation uses.
struct SystemBadge: View {
    let system: AmortizationSystem
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "function").font(.caption2)
            Text("amortization_system_label")
            Text(LocalizedStringKey(system.localizedKey))
        }
        .font(.caption.bold())
        .foregroundStyle(Color.brandBlue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.brandBlue.opacity(0.12), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResultCard(
            labelKey: "calculator_result_monthly",
            value: "1.234,56 €",
            valueColor: .brandBlue,
            isHighlighted: true,
            infoKey: "monthly_payment"
        )
        ResultCard(
            labelKey: "calculator_result_total_interest",
            value: "87.643,20 €",
            valueColor: .brandOrange,
            infoKey: "total_interest"
        )
    }
    .padding()
}
