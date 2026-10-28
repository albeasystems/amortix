//
//  AdConfig.swift
//  amortix
//
//  Unity LevelPlay (ironSource) app key and ad unit IDs, plus interstitial
//  frequency-capping constants. The app key identifies the app in the LevelPlay
//  dashboard; the ad unit IDs are the dashboard's own IDs per format.
//

import Foundation

enum AdConfig {

    /// LevelPlay (Unity) Game ID / App Key for Amortix.
    static let levelPlayAppKey = "2878309ad"

    /// Banner placement per tab. Both tabs share the same LevelPlay ad unit.
    enum Placement {
        case mortgage, amortization
    }

    // The SDK's `adUnitId:` initialisers take the dashboard's ad unit ID, not the
    // ad unit's display name — passing the name yields "Invalid ad unit id".

    static func bannerID(_ placement: Placement) -> String {
        "n3qfzyne1x5s1806"
    }

    static var interstitialID: String {
        "an3dnumlj12hesbh"
    }

    static var rewardedID: String {
        "zxmrf6kcgiwerows"
    }

    /// `false` while the IDs above are still placeholders, so a debug build does
    /// not spend its startup firing requests that cannot succeed and burying the
    /// real logs under "Invalid ad unit id".
    static var isConfigured: Bool {
        !levelPlayAppKey.hasPrefix("TODO_")
    }

    // MARK: - Rewarded

    /// How long ads stay off after the user completes a rewarded video.
    /// Watching again while a window is open extends it rather than restarting it.
    static let rewardedAdFreeDuration: TimeInterval = 3600   // 1 hour

    // MARK: - Interstitial frequency capping

    /// Key actions between interstitials. The counter runs ALWAYS — the grace and
    /// cooldown below only decide whether an ad may be *shown*, never whether an
    /// action counts. Discarding actions is how a short session ends up producing
    /// no impression at all.
    static let successfulActionsRequiredForInterstitial = 3

    /// Minimum time between two interstitials actually shown.
    static let interstitialCooldown: TimeInterval = 300   // 5 minutes

    /// Window after a session starts during which no interstitial is shown, so the
    /// app never opens straight into an ad. Short on purpose: a session here is
    /// often only a minute or two long, and a long grace silently eats it whole.
    static let startupGracePeriod: TimeInterval = 30

    /// Hard ceiling per session, the guardrail that keeps the shorter cooldown
    /// from turning a long session into a slideshow. A session restarts after 30
    /// minutes away from the app (see `AdsManager.noteNewSession()`).
    static let maxInterstitialsPerSession = 3

    /// Seconds after entering the app at which the session's one "slot" fires:
    /// the rating prompt if it can be asked, otherwise the interstitial. See
    /// `ReviewManager`.
    static let sessionSlotDelay: TimeInterval = 30

    /// How long the session-slot interstitial waits for fill before giving up.
    ///
    /// That ad fires thirty seconds into the session, which on a cold start can be
    /// before the very first auction has come back. Giving up instantly there
    /// would waste the one slot of the session; waiting a few seconds turns a
    /// slow fill into a shown ad. On timeout the action counter is left at the
    /// threshold, so the next calculation shows it instead.
    static let firstActionAdWaitTimeout: TimeInterval = 8

    /// Exponential backoff when a load fails (seconds): starts at `base`, doubles
    /// up to `max`, resets on a successful load. Fill is intermittent, so the
    /// first retries have to be quick — a flat minute means a two-minute session
    /// gets barely one attempt.
    static let interstitialBaseRetryDelay: TimeInterval = 4
    static let interstitialMaxRetryDelay: TimeInterval = 64

    // MARK: - Review prompt coordination

    /// Seconds of grace after the rating prompt during which no interstitial is
    /// shown, so the user never gets an ad right on the heels of being asked to
    /// rate. The other half of the deal — no interstitial *before* the first
    /// prompt — lives in `ReviewManager.allowsInterstitials`.
    ///
    /// After a rating prompt the interstitial waits this long, and
    /// `ReviewManager` schedules it for exactly that moment, so a user who was
    /// asked to rate at 0:30 sees their first ad at 1:30.
    static let postReviewGrace: TimeInterval = 60
}
