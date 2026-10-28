import SwiftUI

struct AmortizationTableView: View {
    let result: MortgageResult
    @AppStorage("selectedCountry") private var selectedCountry: String = CountryMarket.spain.rawValue
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var currencyCode: String {
        CountryMarket(rawValue: selectedCountry)?.currencyCode ?? "EUR"
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle("table_nav_title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - iPhone layout
    private var iPhoneLayout: some View {
        List {
            Section {
                AmortizationChartView(rows: result.amortizationTable)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                headerRow
                ForEach(result.amortizationTable) { row in
                    tableRow(row)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - iPad layout
    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            AmortizationChartView(rows: result.amortizationTable)
                .padding()
                .frame(maxWidth: 400)

            Divider()

            List {
                Section { headerRow }
                Section {
                    ForEach(result.amortizationTable) { row in
                        tableRow(row)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Rows
    private var headerRow: some View {
        HStack {
            Text("table_col_period")
                .frame(maxWidth: 40, alignment: .leading)
            Spacer()
            Text("table_col_principal")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("table_col_interest")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("table_col_balance")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func tableRow(_ row: AmortizationRow) -> some View {
        let code = currencyCode
        return HStack {
            Text("\(row.id)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 40, alignment: .leading)
            Spacer()
            Text(row.principal.asCurrency(code))
                .font(.caption)
                .foregroundStyle(Color.brandBlue)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(row.interest.asCurrency(code))
                .font(.caption)
                .foregroundStyle(Color.brandOrange)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(row.balance.asCurrency(code))
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Export
    private var exportText: String {
        let code   = currencyCode
        let header = "Período\tCuota\tCapital\tIntereses\tSaldo\n"
        let rows   = result.amortizationTable.map {
            "\($0.id)\t\($0.payment.asCurrency(code))\t\($0.principal.asCurrency(code))\t\($0.interest.asCurrency(code))\t\($0.balance.asCurrency(code))"
        }.joined(separator: "\n")
        return header + rows
    }
}

#Preview {
    let input = MortgageInput(capital: 200_000, years: 30, tin: 3.5)
    let result = FinancialCalculator.mortgageResult(input: input)
    return NavigationStack {
        AmortizationTableView(result: result)
    }
}
