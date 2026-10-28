import Foundation

// MARK: - Country / Market

enum CountryMarket: String, CaseIterable, Identifiable, Codable {
    case spain   = "es"
    case usa     = "en"
    case india   = "hi"
    case brazil  = "pt-BR"
    case italy   = "it"
    case france  = "fr"
    case germany = "de"
    case arabic  = "ar"

    var id: String { rawValue }

    var localizedKey: String { "country_\(rawValue.replacingOccurrences(of: "-", with: "_"))" }
    var lawKey:       String { "law_\(rawValue.replacingOccurrences(of: "-", with: "_"))" }
    var flagEmoji:    String {
        switch self {
        case .spain:   return "🇪🇸"
        case .usa:     return "🇺🇸"
        case .india:   return "🇮🇳"
        case .brazil:  return "🇧🇷"
        case .italy:   return "🇮🇹"
        case .france:  return "🇫🇷"
        case .germany: return "🇩🇪"
        case .arabic:  return "🇸🇦"
        }
    }

    var currencyCode: String {
        switch self {
        case .spain, .italy, .france, .germany: return "EUR"
        case .usa:    return "USD"
        case .india:  return "INR"
        case .brazil: return "BRL"
        case .arabic: return "SAR"
        }
    }

    /// Short English display name used in the country picker label.
    var displayName: String {
        switch self {
        case .spain:   return "España"
        case .usa:     return "United States"
        case .india:   return "India"
        case .brazil:  return "Brasil"
        case .italy:   return "Italia"
        case .france:  return "France"
        case .germany: return "Deutschland"
        case .arabic:  return "عربي / Gulf"
        }
    }

    var usesEuribor: Bool {
        switch self {
        case .spain, .italy, .france, .germany: return true
        default: return false
        }
    }

    var locale: Locale {
        switch self {
        case .spain:   return Locale(identifier: "es_ES")
        case .usa:     return Locale(identifier: "en_US")
        case .india:   return Locale(identifier: "hi_IN")
        case .brazil:  return Locale(identifier: "pt_BR")
        case .italy:   return Locale(identifier: "it_IT")
        case .france:  return Locale(identifier: "fr_FR")
        case .germany: return Locale(identifier: "de_DE")
        case .arabic:  return Locale(identifier: "ar_SA")
        }
    }

    // MARK: - Commission law per country
    //
    // Spain:   Ley 5/2019 hipotecaria
    // USA:     Dodd-Frank Act (2014) – QM loans max 3%/2%/1% years 1-2-3, 0% after
    // India:   RBI Circular 2012 – 0% floating, max 2% fixed
    // Brazil:  SFH Lei 9.514/1997 – max 2%
    // Italy:   TUB Dlgs 385/1993 + EU Mortgage Directive – 0.5% variable, 1.5% fixed
    // France:  Code de la Consommation L313-47 – IRA = min(3% capital, 6 months interest)
    // Germany: § 490 BGB Vorfälligkeitsentschädigung – max 1% (>12 months), 0.5% (≤12 months)
    // Arabic:  Islamic (Murabaha/Ijara) ~0-1%; conventional ~1-3%

    func earlyRepaymentCommission(
        amount: Double,
        mortgageType: MortgageType,
        yearsSinceSigning: Int,
        monthlyRate: Double,
        remainingMonths: Int
    ) -> Double {
        switch self {
        case .spain:
            switch mortgageType {
            case .variable:
                return yearsSinceSigning < 3 ? amount * 0.0025 : 0
            case .fixed, .mixed:
                return yearsSinceSigning < 10 ? amount * 0.02 : amount * 0.015
            }
        case .usa:
            if yearsSinceSigning < 1 { return amount * 0.03 }
            if yearsSinceSigning < 2 { return amount * 0.02 }
            if yearsSinceSigning < 3 { return amount * 0.01 }
            return 0
        case .india:
            return mortgageType == .variable ? 0 : amount * 0.02
        case .brazil:
            return amount * 0.02
        case .italy:
            return mortgageType == .variable ? amount * 0.005 : amount * 0.015
        case .france:
            let cap3pct        = amount * 0.03
            let cap6months     = amount * monthlyRate * 6
            return min(cap3pct, max(0, cap6months))
        case .germany:
            return remainingMonths > 12 ? amount * 0.01 : amount * 0.005
        case .arabic:
            return amount * 0.01
        }
    }
}
