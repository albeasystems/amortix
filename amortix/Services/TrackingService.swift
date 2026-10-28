import AppTrackingTransparency
import UIKit
import os

/// Requests the user's App Tracking Transparency permission before any data
/// used to track them (advertising data, device identifiers) is collected.
///
/// The ads SDK must only initialise once this has resolved: Meta's adapter reads
/// `ATTrackingManager`'s status directly at init time on iOS 17+, so starting
/// LevelPlay while the prompt is still on screen permanently registers the
/// install as non-tracked. `AmortixApp` therefore awaits
/// `requestAuthorizationIfNeeded()` before `ConsentService` and `AdsManager`.
@MainActor
enum TrackingService {

    private static let hasRequestedKey = "att_has_requested"
    private static let log = Logger(subsystem: "com.albeasystems.amortix", category: "tracking")

    /// Pause after the app turns active before asking. Lets the launch
    /// transition and the first frame settle, which is when iOS is willing to
    /// put the alert up.
    private static let settleDelay: Duration = .seconds(1)

    /// Attempts per launch. Each one waits for the app to be active first, so
    /// this only bounds the case where iOS keeps declining to show the alert.
    private static let maxAttempts = 5

    /// Shows the system ATT prompt if the user hasn't been asked yet, and does
    /// not return until they have answered.
    ///
    /// WHY IT WAITS FOR `.active` AND CHECKS THE RESULT.
    ///
    /// iOS only presents the alert while the app is active. Asked any earlier —
    /// at cold launch the `.task` that drives this runs before the scene has
    /// finished activating — the request is dropped without any alert, the
    /// completion still fires, and the status comes back `.notDetermined`.
    /// The previous version slept a fixed 250 ms and asked once: fast enough on
    /// the simulator, too early on a cold launch on a real device, which is how
    /// App Review ended up never seeing the prompt (Guideline 2.1, iOS 26.6.2).
    ///
    /// So: wait until the app is actually active, give it a moment, ask, and if
    /// the answer is still `.notDetermined` — meaning no alert was shown — try
    /// again. Any other status means iOS resolved the request: the user
    /// answered, or tracking is switched off in Settings or by a profile, in
    /// which case iOS answers `.denied`/`.restricted` without showing anything.
    static func requestAuthorizationIfNeeded() async {
        guard status == .notDetermined else {
            log.log("ATT already resolved — status \(status.rawValue)")
            return
        }

        for attempt in 1...maxAttempts {
            await waitUntilAppIsActive()
            try? await Task.sleep(for: settleDelay)
            if Task.isCancelled { return }
            // Might have gone to the background during the pause.
            guard UIApplication.shared.applicationState == .active else { continue }

            log.log("requesting ATT authorization (attempt \(attempt))")
            let result = await ATTrackingManager.requestTrackingAuthorization()
            UserDefaults.standard.set(true, forKey: hasRequestedKey)

            if result != .notDetermined {
                log.log("ATT resolved — status \(result.rawValue) (0 notDetermined, 1 restricted, 2 denied, 3 authorized)")
                return
            }
            log.error("ATT request returned notDetermined — the alert was not shown, retrying")
        }
        // Still undetermined: no IDFA is available, so nothing can track. The
        // next launch asks again.
        log.error("ATT alert could not be shown after \(maxAttempts) attempts — continuing without IDFA")
    }

    /// Suspends until the app is in the foreground and active. Polls because
    /// there is no async "became active" signal that also covers "already is".
    private static func waitUntilAppIsActive() async {
        while UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { return }
        }
    }

    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    static var isAuthorized: Bool { status == .authorized }
}
