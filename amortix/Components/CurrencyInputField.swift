import SwiftUI

struct CurrencyInputField: View {
    let labelKey:     LocalizedStringKey
    @Binding var text: String
    var suffixKey:    LocalizedStringKey? = nil
    var keyboardType: UIKeyboardType      = .decimalPad

    var body: some View {
        HStack {
            Text(labelKey)
                .layoutPriority(1)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
            if let suffix = suffixKey {
                Text(suffix)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }
}

#Preview {
    Form {
        CurrencyInputField(
            labelKey: "calculator_capital",
            text: .constant("200000"),
            suffixKey: nil
        )
        CurrencyInputField(
            labelKey: "calculator_tin",
            text: .constant("3.5"),
            suffixKey: "%"
        )
    }
}
