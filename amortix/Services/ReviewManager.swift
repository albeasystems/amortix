//
//  ReviewManager.swift
//  amortix
//
//  Asks for the native App Store rating 30 seconds after the user enters the
//  app (cold launch, or coming back after a long absence). Apple caps the prompts it actually DISPLAYS at 3
//  per year; calls the system silently drops don't spend that quota, so asking
//  early and often on our side is cheap.
//
//  Coordination with ads: THE RATING GOES FIRST. It has first claim on the
//  thirty-second slot, and when it passes on it — already asked, still inside its
//  own cooldown — the slot is handed to the interstitial instead of being wasted.
//  When the prompt DOES fire, the interstitial follows `postReviewGrace` (60 s)
//  later. See `fireSessionSlot()`.
//

import StoreKit
import UIKit
import os

@MainActor
final class ReviewManager {

    static let shared = ReviewManager()

    // MARK: - Configuration

    // The rule is a timer started by entering the app, not a counter of
    // calculations: a fixed 30 seconds of use is enough intent, and it does not
    // depend on the user having pressed Calculate.

    /// Seconds between entering the app and the prompt.
    private static var sessionSlotDelay: TimeInterval { AdConfig.sessionSlotDelay }

    /// Escape valve for ads: if the prompt never gets to fire (no active scene,
    /// for instance) interstitials are released after this many actions so we
    /// don't lose monetisation indefinitely. Low, because the prompt fires on the
    /// first calculation in every ordinary flow and this only ever catches the
    /// cases where that failed outright.
    private static let actionsBeforeUnblockingAds = 4

    /// Seconds that must have passed since the last interstitial was dismissed
    /// before firing the prompt (don't ask for a rating with the ad still fresh).
    private static let postInterstitialGrace: TimeInterval = 45

    #if DEBUG
    // Short values so the whole flow can be exercised in the simulator without
    // waiting. They do not affect release builds.
    //
    // NOTE: `minTimeBetweenRequests` cannot be 0. If it were, every action would
    // refresh `lastReviewRequestedAt` and `AdConfig.postReviewGrace` would block
    // the interstitial forever.
    private static let minTimeBetweenRequests: TimeInterval = 300
    private static let newSessionGap: TimeInterval = 20
    #else
    /// Minimum time between two requests of OURS.
    ///
    /// Not to be confused with Apple's limit (3 displayed per year): calls iOS
    /// silently drops don't spend that quota. Hence 30 days rather than 60 — if a
    /// request lands at a bad moment we don't want to lose two months, we want
    /// another shot soon. iOS still decides which ones it shows.
    private static let minTimeBetweenRequests: TimeInterval = 30 * 24 * 3600

    /// Gap away from the app beyond which returning to the foreground counts as a
    /// new session. Stops the counter inflating when switching apps for seconds.
    private static let newSessionGap: TimeInterval = 30 * 60
    #endif

    // MARK: - Persisted state

    private let actionsKey        = "amortix_review_total_actions"
    private let lastRequestKey    = "amortix_review_last_request_ts"
    private let ratedKey          = "amortix_review_rated_manually"
    private let sessionsKey       = "amortix_review_session_count"
    private let lastForegroundKey = "amortix_review_last_foreground_ts"

    /// Number of usage sessions. Incremented by `noteForeground()`.
    private var sessionCount: Int {
        get { UserDefaults.standard.integer(forKey: sessionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: sessionsKey) }
    }

    /// Last time the app was in the foreground. Persisted so the gap is measured
    /// correctly even when iOS kills the process between visits.
    private var lastForegroundDate: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: lastForegroundKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastForegroundKey)
        }
    }

    /// `true` if the user went to rate the app on their own from Settings.
    ///
    /// Apple does not tell us whether anyone rated: `requestReview` has neither a
    /// callback nor a return value. That bookkeeping lives in iOS (max 3 prompts
    /// displayed per year, and it won't re-ask someone who already rated this
    /// version), not here.
    ///
    /// All we know is that they tapped "Valorar la app" and we opened the App
    /// Store page. That does NOT prove they rated — they could have backed out.
    /// So this flag does not silence the automatic prompt; it only releases the
    /// interstitials, because if they already went to rate there is no pending
    /// rating left to protect.
    private var hasRatedManually: Bool {
        get { UserDefaults.standard.bool(forKey: ratedKey) }
        set { UserDefaults.standard.set(newValue, forKey: ratedKey) }
    }

    private var totalActions: Int {
        get { UserDefaults.standard.integer(forKey: actionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: actionsKey) }
    }

    private var lastRequestDate: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: lastRequestKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastRequestKey)
        }
    }

    // MARK: - In-memory state

    /// When the prompt was fired; `AdsManager` reads it to honour the post-review
    /// grace before showing an interstitial.
    private(set) var lastReviewRequestedAt: Date?

    /// The pending thirty-second countdown started by entering the app. Cancelled
    /// if the user leaves before it fires — there is no point asking for stars, or
    /// showing an ad, into an empty screen.
    private var sessionSlotTask: Task<Void, Never>?

    /// The follow-up that shows the interstitial `postReviewGrace` after a prompt.
    private var postReviewAdTask: Task<Void, Never>?

    /// `true` from the start of a session until its slot has fired. If the user
    /// backgrounds the app before then, coming back restarts the countdown.
    private var sessionSlotPending = false

    /// `true` once the app has been backgrounded since the last activation. In
    /// memory on purpose: if iOS kills the process while suspended, the next
    /// launch goes through the `countedThisProcess` branch instead.
    private var wentToBackground = false

    /// `true` once this process's initial activation has been evaluated.
    private var countedThisProcess = false

    private static let log = Logger(subsystem: "com.albeasystems.amortix", category: "review")

    private init() {}

    // MARK: - Lifecycle

    /// Call at launch AND every time the app returns to the foreground.
    ///
    /// Counting sessions on cold launch alone is not enough: iOS keeps apps
    /// resident for a long time, so a user can open the app dozens of times from
    /// the app switcher without any launch code running again.
    ///
    /// Idempotent: extra calls don't inflate the counter, because a new session is
    /// only counted when the gap away from the app exceeds `newSessionGap`.
    func noteForeground() {
        let now = Date()

        // Only two things start a session: the process launching, or coming back
        // from the background. An `.inactive` → `.active` cycle does NOT count: it
        // happens with system dialogs (ATT, consent), Control Centre or a phone
        // call, and the user never left the app there.
        //
        // This filter is essential: on the way BACK, iOS passes through
        // `.inactive` before `.active`, so trying to infer it from the timestamp
        // alone fails — it would be rewritten just before being measured and the
        // gap would always come out as ~0.
        guard !countedThisProcess || wentToBackground else { return }

        let isColdLaunch = !countedThisProcess
        let gap = lastForegroundDate.map { now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        countedThisProcess = true
        wentToBackground = false
        lastForegroundDate = now

        if gap >= Self.newSessionGap {
            sessionCount += 1
            Self.log.debug("review — session \(self.sessionCount), lifetime actions: \(self.totalActions)")
            // This object is the one measuring the gap away from the app, so it is
            // the one that can tell AdsManager when a new session starts.
            AdsManager.shared.noteNewSession()
            sessionSlotPending = true
        } else if isColdLaunch {
            // A relaunch inside the gap is not a new session for pacing purposes,
            // but the user did just enter the app, so the slot still applies.
            sessionSlotPending = true
        }

        // Also restarts a countdown that was cancelled by a short trip to the
        // background before it had a chance to fire.
        if sessionSlotPending { startSessionSlotCountdown() }
    }

    /// Call when the app goes to the background (`.background`, NOT `.inactive`).
    func noteBackground() {
        wentToBackground = true
        lastForegroundDate = Date()
        // Don't let a countdown started just before leaving fire into a screen the
        // user is no longer looking at.
        sessionSlotTask?.cancel()
        sessionSlotTask = nil
        postReviewAdTask?.cancel()
        postReviewAdTask = nil
    }

    // MARK: - Interstitial gate
    //
    // THE RATING GOES FIRST. A user who has been shown an interstitial before
    // being asked to rate scores worse, so no interstitial is shown until the
    // review prompt has been fired at least once.

    /// `true` once the prompt has been fired (persisted: holding back the first
    /// interstitial happens once in the lifetime of the install).
    var hasRequestedReview: Bool { lastRequestDate != nil }

    /// Read by `AdsManager` before showing any interstitial.
    var allowsInterstitials: Bool {
        hasRequestedReview || hasRatedManually || totalActions >= Self.actionsBeforeUnblockingAds
    }

    // MARK: - Public API

    /// Call at the same points as `AdsManager.shared.registerKeyAction()`, and
    /// always BEFORE it. Only feeds the escape valve: the prompt itself is driven
    /// by the session timer, not by calculations.
    func registerKeyAction() {
        totalActions += 1
        Self.log.debug("review — action \(self.totalActions)")
    }

    /// A SECONDARY interaction: opening a KPI's detail sheet from its "i" button.
    ///
    /// Counts towards the escape valve and — via `AdsManager` — towards the
    /// interstitial pacing, because someone reading the breakdown of their own
    /// figures is engaged, and that engagement would otherwise be worth nothing.
    ///
    func registerSecondaryAction() {
        totalActions += 1
        Self.log.debug("review — secondary action \(self.totalActions)")
    }

    /// Call when the user taps "Valorar la app" in Settings (which opens the App
    /// Store page with `?action=write-review`).
    ///
    /// Applies the NORMAL cooldown, not a permanent silence: opening the page is
    /// no proof they rated. The real "already rated" suppression is done by iOS.
    func markRatedManually() {
        hasRatedManually = true          // releases the interstitials
        lastRequestDate = Date()         // normal, reversible cooldown
        lastReviewRequestedAt = Date()   // honour the post-review grace
        Self.log.log("user went to rate from Settings — normal cooldown applied")
    }

    // MARK: - Internals

    /// Starts (or restarts) the session's one countdown.
    private func startSessionSlotCountdown() {
        Self.log.log("review — session slot firing in \(Int(Self.sessionSlotDelay))s")
        sessionSlotTask?.cancel()
        sessionSlotTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.sessionSlotDelay))
            // Not while onboarding is still on screen: asking for stars before the
            // user has seen the app would be wasted, and ads never belong there.
            while !Task.isCancelled, !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                try? await Task.sleep(for: .seconds(5))
            }
            guard !Task.isCancelled, let self else { return }
            self.sessionSlotPending = false
            self.fireSessionSlot()
        }
    }

    /// The rating prompt gets the slot; if it cannot take it, the interstitial
    /// does. One or the other fires here — never both, and never neither. When
    /// the prompt fires, the interstitial is scheduled `postReviewGrace` later.
    private func fireSessionSlot() {
        if requestReviewIfPossible() {
            scheduleInterstitialAfterReview()
            return
        }
        Self.log.log("review — passed on the slot, handing it to the interstitial")
        AdsManager.shared.showInterstitialAfterFirstAction()
    }

    /// 60 seconds after the prompt, hand the next ad its turn. The small margin
    /// keeps the timer from landing a hair inside the grace window it is waiting
    /// out, which would make `AdsManager` skip the ad it was woken up to show.
    private func scheduleInterstitialAfterReview() {
        postReviewAdTask?.cancel()
        postReviewAdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AdConfig.postReviewGrace + 0.5))
            guard !Task.isCancelled else { return }
            AdsManager.shared.showInterstitialAfterFirstAction()
        }
    }

    /// Returns `true` when the prompt was actually handed to StoreKit.
    @discardableResult
    private func requestReviewIfPossible() -> Bool {
        if let last = lastRequestDate {
            guard Date().timeIntervalSince(last) >= Self.minTimeBetweenRequests else {
                Self.log.debug("review — skipped: cooldown active (last: \(last, privacy: .public))")
                return false
            }
        }

        if let lastAd = AdsManager.shared.lastInterstitialClosedAt {
            guard Date().timeIntervalSince(lastAd) >= Self.postInterstitialGrace else {
                Self.log.debug("review — skipped: recent interstitial")
                return false
            }
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            Self.log.debug("review — skipped: no active foreground scene")
            return false
        }

        Self.log.log("requesting review (lifetime actions: \(self.totalActions), session \(self.sessionCount))")
        lastReviewRequestedAt = Date()
        lastRequestDate = Date()

        // `SKStoreReviewController` was deprecated in iOS 18 in favour of
        // `AppStore.requestReview(in:)`. The old path stays for the 16.6
        // deployment target.
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        return true
    }

    #if DEBUG
    /// Wipes the persisted state so the flow can be tested from scratch.
    func debugReset() {
        UserDefaults.standard.removeObject(forKey: actionsKey)
        UserDefaults.standard.removeObject(forKey: lastRequestKey)
        UserDefaults.standard.removeObject(forKey: ratedKey)
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: lastForegroundKey)
        lastReviewRequestedAt = nil
        sessionSlotPending = false
        sessionSlotTask?.cancel()
        sessionSlotTask = nil
        postReviewAdTask?.cancel()
        postReviewAdTask = nil
        Self.log.debug("review — state reset")
    }
    #endif
}
