import SwiftUI

/// Full-screen numpad for entering large monetary values.
/// Presented as a sheet; commits on "Done", discards on "Cancel".
struct NumericKeypadSheet: View {
    let labelKey:  LocalizedStringKey
    let symbolKey: String          // currency code or unit label
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                displayArea
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)

                Divider()

                keypadGrid
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(labelKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("general_cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("general_done") { commit() }
                        .font(.headline)
                        .foregroundStyle(Color.brandBlue)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { draft = text }
    }

    // MARK: - Display

    private var displayArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(symbolKey)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.brandBlue.opacity(0.12))
                    .foregroundStyle(Color.brandBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if draft.isEmpty {
                    Text("0")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.placeholderText))
                } else {
                    Text(displayDraft)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
            }
        }
    }

    private var displayDraft: String {
        // Show thousands-separated integer part, raw decimal part
        let parts = draft.components(separatedBy: ".")
        let intPart = parts[0]
        let formatted = (Double(intPart) ?? 0)
            .formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
        if parts.count == 2 {
            return formatted + "." + parts[1]
        }
        return formatted
    }

    // MARK: - Keypad

    private var keypadGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow { numKey("7"); numKey("8"); numKey("9") }
            GridRow { numKey("4"); numKey("5"); numKey("6") }
            GridRow { numKey("1"); numKey("2"); numKey("3") }
            GridRow { numKey("."); numKey("0"); deleteKey }
        }
    }

    private func numKey(_ k: String) -> some View {
        Button {
            HapticService.selection()
            handleKey(k)
        } label: {
            Text(k)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .foregroundStyle(.primary)
        }
    }

    private var deleteKey: some View {
        Button {
            HapticService.selection()
            if !draft.isEmpty { draft.removeLast() }
        } label: {
            Image(systemName: "delete.backward")
                .font(.title3)
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(Color.brandRed.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .foregroundStyle(Color.brandRed)
        }
    }

    // MARK: - Input logic

    private func handleKey(_ key: String) {
        switch key {
        case ".":
            guard !draft.contains(".") else { return }
            draft = draft.isEmpty ? "0." : draft + "."
        default:
            if draft == "0" { draft = key; return }
            // Cap at 2 decimal places
            if let dot = draft.firstIndex(of: ".") {
                let decimals = draft.distance(from: draft.index(after: dot), to: draft.endIndex)
                if decimals >= 2 { return }
            }
            // Prevent excessively long integers (12 digits max)
            let intPart = draft.components(separatedBy: ".").first ?? draft
            if !draft.contains("."), intPart.count >= 12 { return }
            draft += key
        }
    }

    private func commit() {
        var clean = draft
        if clean.hasSuffix(".") { clean.removeLast() }
        text = clean.isEmpty ? "" : clean
        dismiss()
    }
}

#Preview {
    NumericKeypadSheet(labelKey: "Capital", symbolKey: "EUR", text: .constant("150000"))
}
