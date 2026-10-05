import SwiftUI

extension View {

    func adaptiveMaxWidth(_ width: CGFloat = 720) -> some View {
        frame(maxWidth: width)
    }

    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func premiumBlur(isLocked: Bool) -> some View {
        self
            .blur(radius: isLocked ? 8 : 0)
            .disabled(isLocked)
            .animation(.easeInOut(duration: 0.2), value: isLocked)
    }

    func sectionHeader(_ key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            self
        }
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
