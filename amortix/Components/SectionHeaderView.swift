import SwiftUI

struct SectionHeaderView: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let img = systemImage {
                Image(systemName: img)
            }
            Text(titleKey)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SectionHeaderView(titleKey: "calculator_section_loan", systemImage: "house.fill")
        .padding()
}
