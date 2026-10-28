import SwiftUI

@main
struct AmortixApp: App {

    @AppStorage("selectedLanguage") private var selectedLanguage: String = ""

    private var activeLocale: Locale {
        selectedLanguage.isEmpty ? .autoupdatingCurrent : Locale(identifier: selectedLanguage)
    }

    init() {
        // Boot StoreKit listener and pre-load the product so Settings has the
        // price ready when opened.
        _ = StoreService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(selectedLanguage)
                .environment(\.locale, activeLocale)
        }
    }
}

/// Root container: onboarding once, then the tabs — plus the startup sequence
/// and the session bookkeeping the rating prompt and the ads pacing depend on.
private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            // Cold launch. `onChange(of: scenePhase)` does not fire for the
            // initial `.active`, so the first session is counted here; the call is
            // idempotent, and the `.inactive` -> `.active` cycle caused by the ATT
            // and consent dialogs below does not count as a second one.
            ReviewManager.shared.noteForeground()

            // ORDER MATTERS. First the first-launch ATT prompt, then the GDPR/CMP
            // flow, and only then the ads SDK: Meta reads ATTrackingManager's
            // status directly at init time on iOS 17+, and AdMob will not fill
            // EEA/UK traffic without a consent record on file.
            await TrackingService.requestAuthorizationIfNeeded()
            await ConsentService.shared.resolve()
            AdsManager.shared.start()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // Where sessions are really counted: reopening from the app
                // switcher never runs launch code again.
                ReviewManager.shared.noteForeground()
            case .background:
                // `.background` only. NOT `.inactive`: that fires for system
                // dialogs and also on the way back in, so recording it there would
                // wipe the timestamp right before it can be measured.
                ReviewManager.shared.noteBackground()
            default:
                break
            }
        }
    }
}
