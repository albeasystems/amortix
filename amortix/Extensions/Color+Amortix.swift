import SwiftUI

extension Color {
    static let brandBlue   = Color(hex: "2269DE")
    static let brandTeal   = Color(hex: "10A594")
    static let brandOrange = Color(hex: "FF941A")
    static let brandRed    = Color(hex: "ED4242")
    static let brandGreen  = Color(hex: "2EBA6B")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
