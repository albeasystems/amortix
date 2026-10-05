import SwiftUI
import GoogleMobileAds

@main
struct AmortixApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isPremiumUnlocked") private var isPremiumUnlocked = false

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        await AppTrackingService.shared.requestTrackingIfNeeded()
                    }
            } else {
                OnboardingView()
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        await AppTrackingService.shared.requestTrackingIfNeeded()
                    }
            }
        }
    }
}
