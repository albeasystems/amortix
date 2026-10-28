import Combine
import SwiftUI

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system  = ""
    case es, en, fr, it, de, pt, ar, hi
    case zhHans  = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:  return "🌐 System"
        case .es:      return "🇪🇸 Español"
        case .en:      return "🇺🇸 English"
        case .fr:      return "🇫🇷 Français"
        case .it:      return "🇮🇹 Italiano"
        case .de:      return "🇩🇪 Deutsch"
        case .pt:      return "🇧🇷 Português"
        case .ar:      return "🇸🇦 العربية"
        case .hi:      return "🇮🇳 हिंदी"
        case .zhHans:  return "🇨🇳 中文"
        }
    }

    var locale: Locale {
        rawValue.isEmpty ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }
}

// MARK: - SettingsViewModel

final class SettingsViewModel: ObservableObject {

    // MARK: - Language (persisted)
    // Backed directly by UserDefaults; views read it through their own
    // @AppStorage, so it deliberately does not publish from here.
    @AppStorage("selectedLanguage") var selectedLanguage: String = ""

    var selectedAppLanguage: AppLanguage {
        get { AppLanguage(rawValue: selectedLanguage) ?? .system }
        set { selectedLanguage = newValue.rawValue }
    }

    // MARK: - Premium (persisted)
    @AppStorage("isPremiumUnlocked") var isPremiumUnlocked = false

    // MARK: - Easter egg
    private var tapCount:    Int  = 0
    private var lastTapTime: Date = .distantPast

    @Published var showPremiumAlert:     Bool = false
    @Published var premiumAlertIsUnlock: Bool = true

    // MARK: - App info
    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    // App Store identifiers
    static let appStoreID = "6773757657"

    var websiteURL:       URL { URL(string: "https://albeasystems.github.io/amortix/")! }
    var privacyPolicyURL: URL { URL(string: "https://albeasystems.github.io/amortix/privacy.html")! }
    var termsOfUseURL:    URL { URL(string: "https://albeasystems.github.io/amortix/terms.html")! }
    var supportURL:       URL { URL(string: "https://albeasystems.github.io/amortix/support.html")! }

    var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)")!
    }

    var feedbackURL: URL {
        URL(string: "mailto:support@albeasystems.com?subject=Amortix%20Feedback")!
    }

    var rateAppURL: URL {
        URL(string: "itms-apps://apps.apple.com/app/id\(Self.appStoreID)?action=write-review")!
    }

    // MARK: - Easter egg handler (20 taps in 10s → toggle premium/ads)
    //
    // DEBUG-only: in production we must not let a paying user accidentally
    // revoke their own StoreKit-backed entitlement by tapping the version row.
    func handleSecretTap() {
#if DEBUG
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 10 { tapCount = 0 }
        tapCount    += 1
        lastTapTime  = now

        if tapCount == 20 {
            tapCount             = 0
            isPremiumUnlocked    = !isPremiumUnlocked
            premiumAlertIsUnlock = isPremiumUnlocked
            HapticService.premiumToggle()
            showPremiumAlert     = true
        }
#endif
    }

    var premiumAlertTitle: LocalizedStringKey {
        isPremiumUnlocked ? "premium_unlock_title" : "premium_lock_title"
    }

    var premiumAlertMessage: LocalizedStringKey {
        isPremiumUnlocked ? "premium_unlock_message" : "premium_lock_message"
    }
}
