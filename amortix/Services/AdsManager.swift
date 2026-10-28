//
//  AdsManager.swift
//  amortix
//
//  Unity LevelPlay (ironSource SDK 8.x) orchestration. The whole IronSource-dependent
//  implementation is guarded by `#if canImport(IronSource)` so the app still
//  compiles and runs if the pod is not linked; a no-op stub is used in that case.
//
//  Premium users never see ads: every entry point checks `isPremiumUnlocked`.
//
//  Call order: `start()` must run after App Tracking Transparency is resolved,
//  and it only initialises the SDK when the CMP allows ad requests
//  (`ConsentService.canRequestAds`). Nothing loads before `isInitialized` flips
//  true, so without consent no ad is ever requested.
//

import SwiftUI
import UIKit
import Combine
import os

// The project must be built from amortix.xcworkspace. Built from
// amortix.xcodeproj the pods are not linked, every ads file falls back to its
// no-op stub, and the app runs without ads and without any visible sign of it.
// Debug builds warn; release builds refuse to compile, so it can never ship.
#if !canImport(IronSource) || !canImport(UserMessagingPlatform)
#if DEBUG
#warning("LevelPlay/UMP not linked — open amortix.xcworkspace, not amortix.xcodeproj. This build shows no ads.")
#else
#error("LevelPlay/UMP not linked. Build from amortix.xcworkspace (after `pod install`), never amortix.xcodeproj — otherwise the release ships without ads.")
#endif
#endif

#if canImport(IronSource)
import IronSource
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var isInitialized = false {
        didSet {
            guard isInitialized, !oldValue else { return }
            preloadInterstitial()
            preloadRewarded()
        }
    }

    /// When the ad-free window earned from a rewarded video expires, or nil when
    /// there is none. Persisted so it survives a relaunch inside the hour.
    @Published private(set) var adFreeUntil: Date?

    @Published private(set) var isRewardedReady = false

    private(set) var isInterstitialReady = false
    private var interstitialAd: LPMInterstitialAd?
    /// Stops a burst of key actions from stacking up parallel load requests while
    /// one is already on the wire.
    private var interstitialLoadInFlight = false
    private var interstitialLoadStartedAt: Date?
    /// After this long an in-flight load is treated as lost. Without it, a request
    /// whose delegate never fires would wedge the flag and kill every later load.
    /// No-fill answers have been measured taking ~25s, so this sits well above that.
    private static let interstitialLoadTimeout: TimeInterval = 90

    private var rewardedAd: LPMRewardedAd?
    /// The SDK holds ad delegates weakly, and this one cannot be `self`: the
    /// interstitial and rewarded delegate protocols declare the same selectors.
    private var rewardedDelegate: RewardedAdDelegate?
    private var rewardedRetryTask: Task<Void, Never>?
    private var adFreeExpiryTask: Task<Void, Never>?

    private static let adFreeUntilKey = "adFreeUntil"

    private var isShowingInterstitial = false

    /// Set while `LevelPlay.initWith` is in flight, so a second `start()` (the
    /// privacy-options form closing, a re-run of the startup task) cannot fire a
    /// parallel init.
    private var isStarting = false

    /// Start of the current usage session, reset by `noteNewSession()`. If it
    /// only ever meant cold launch, coming back to the app after hours would get
    /// no startup grace at all and the ad could fire on the first action back.
    private var launchDate = Date()
    private var successfulActionsSinceLastInterstitial = 0
    private var lastInterstitialShown = Date.distantPast
    /// When the last interstitial was dismissed. `ReviewManager` reads it so it
    /// doesn't fire the rating prompt right after an ad.
    private(set) var lastInterstitialClosedAt: Date?
    /// Interstitials already shown in this session, against `maxInterstitialsPerSession`.
    private var interstitialsThisSession = 0
    private var interstitialRetryTask: Task<Void, Never>?
    /// Current backoff delay; doubles on each failed load, resets on success.
    private var interstitialRetryDelay = AdConfig.interstitialBaseRetryDelay

    private var isPremium: Bool {
        UserDefaults.standard.bool(forKey: "isPremiumUnlocked")
    }

    /// No ads right now — either bought forever, or earned for the hour.
    var isAdFree: Bool {
        isPremium || (adFreeUntil.map { $0 > Date() } ?? false)
    }

    private static let log = Logger(subsystem: "com.albeasystems.amortix", category: "ads")

    private override init() {
        super.init()
        if let stored = UserDefaults.standard.object(forKey: Self.adFreeUntilKey) as? Date,
           stored > Date() {
            adFreeUntil = stored
            scheduleAdFreeExpiry()
        } else {
            UserDefaults.standard.removeObject(forKey: Self.adFreeUntilKey)
        }
    }

    // MARK: - Startup

    func start() {
        guard !isInitialized, !isStarting else { return }

        // No ad request without the CMP's go-ahead. `canRequestAds` is true where
        // consent is not required, and in the EEA/UK once the user has answered
        // the form (whatever they chose: a refusal still allows limited,
        // non-personalised ads). It is false while the form is unanswered or the
        // consent status could not be fetched. `ConsentService` calls back here
        // when the answer comes in later.
        guard ConsentService.shared.canRequestAds else {
            Self.log.log("LevelPlay not started — the CMP does not allow ad requests yet")
            return
        }

        // The dashboard IDs have not been filled in yet (see AdConfig). Asking
        // the SDK anyway only produces a stream of "Invalid ad unit id" that
        // buries every other log line.
        guard AdConfig.isConfigured else {
            Self.log.error("LevelPlay not started — AdConfig still holds placeholder IDs")
            return
        }

        #if DEBUG
        LevelPlay.setAdaptersDebug(true)
        ISIntegrationHelper.validateIntegration()
        #if canImport(GoogleMobileAds)
        // AdMob serves real (revenue-generating) ads by default, even in a debug
        // build — without this, testing on a physical device risks the AdMob
        // account being flagged for invalid traffic from repeated dev taps.
        // The hash is per-device (Google derives it from this device's identifier)
        // and gets printed to the console on first launch as "<Google> To get
        // test ads on this device, set: ...testDeviceIdentifiers = [...]" — swap
        // it in, or add more entries, for any other physical device used to test.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers =
            ["ecc83b9bf53fe10f2ad268eec6741996"]
        #endif
        #endif

        let request = LPMInitRequest(appKey: AdConfig.levelPlayAppKey, userId: nil)
        Self.log.log("LevelPlay init requested")
        isStarting = true
        LevelPlay.initWith(request) { config, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isStarting = false
                if let error {
                    Self.log.error("LevelPlay init failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                Self.log.log("LevelPlay initialized")
                self.isInitialized = true
                LevelPlay.add(self)
            }
        }
    }

    func bannerRootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController
    }

    // MARK: - Interstitial

    func preloadInterstitial() {
        guard isInitialized else { return }
        loadInterstitial()
    }

    private func loadInterstitial() {
        guard !isAdFree, !isShowingInterstitial else { return }
        guard !isInterstitialReady else { return }
        if interstitialLoadInFlight,
           let started = interstitialLoadStartedAt,
           Date().timeIntervalSince(started) < Self.interstitialLoadTimeout { return }
        interstitialRetryTask?.cancel()
        let ad = LPMInterstitialAd(adUnitId: AdConfig.interstitialID)
        ad.setDelegate(self)
        interstitialAd = ad
        isInterstitialReady = false
        interstitialLoadInFlight = true
        interstitialLoadStartedAt = Date()
        Self.log.log("requesting interstitial load")
        ad.loadAd()
    }

    /// Call when a new usage session begins — decided by `ReviewManager`, which
    /// is what measures the gap away from the app.
    ///
    /// Resets the interstitial's pacing: without this, someone who leaves with the
    /// counter at 2/3 gets the ad on their FIRST action after returning, which is
    /// exactly the most irritating interruption and the one that sinks ratings.
    func noteNewSession() {
        successfulActionsSinceLastInterstitial = 0
        interstitialsThisSession = 0
        launchDate = Date()
        Self.log.log("new session — interstitial pacing reset")
        preloadInterstitial()
    }

    func registerKeyAction() {
        guard !isAdFree, !isShowingInterstitial else { return }

        // COUNT FIRST, gate afterwards. Every guard below decides whether an ad may
        // be shown right now — none of them may decide whether the action counted.
        // Incrementing after the guards silently throws away every action taken
        // during the startup grace or inside the cooldown, which in a calculator
        // app is most of a session: a user doing four calculations in 90 seconds
        // reaches a counter of two and sees no ad at all.
        //
        // The counter is capped at the threshold so a long hold cannot build up a
        // debt that fires the instant the gate opens.
        successfulActionsSinceLastInterstitial = min(
            successfulActionsSinceLastInterstitial + 1,
            AdConfig.successfulActionsRequiredForInterstitial
        )

        // The count above happens even before the SDK is up — init takes seconds and
        // those first actions are real. Everything below needs a live SDK.
        guard isInitialized else { return }

        guard successfulActionsSinceLastInterstitial >= AdConfig.successfulActionsRequiredForInterstitial else {
            preloadInterstitial()   // next action may well be the one
            return
        }
        guard Date().timeIntervalSince(launchDate) >= AdConfig.startupGracePeriod else { return }
        guard Date().timeIntervalSince(lastInterstitialShown) >= AdConfig.interstitialCooldown else { return }
        guard interstitialsThisSession < AdConfig.maxInterstitialsPerSession else {
            Self.log.log("interstitial capped — \(self.interstitialsThisSession) already shown this session")
            return
        }

        // The rating goes FIRST: hold the interstitial back until the review
        // prompt has been fired at least once, so an ad never gets to sour the
        // user right before we ask them for stars.
        guard ReviewManager.shared.allowsInterstitials else {
            Self.log.log("interstitial held back — rating not requested yet")
            return
        }

        // And don't follow the prompt straight away with an ad either.
        if let lastReview = ReviewManager.shared.lastReviewRequestedAt,
           Date().timeIntervalSince(lastReview) < AdConfig.postReviewGrace {
            Self.log.log("interstitial deferred — recent rating prompt")
            return
        }

        showInterstitialIfReady()
    }

    /// Counts a SECONDARY interaction — opening a KPI's detail sheet — towards the
    /// interstitial pacing, without ever showing one from here.
    ///
    /// Exploring the results is real engagement and has to bring the next ad
    /// closer. But the ad itself must land on a calculation: firing it from the
    /// "i" button would drop a full-screen ad straight on top of the explanation
    /// the user just opened.
    func registerSecondaryAction() {
        guard !isAdFree, !isShowingInterstitial else { return }
        successfulActionsSinceLastInterstitial = min(
            successfulActionsSinceLastInterstitial + 1,
            AdConfig.successfulActionsRequiredForInterstitial
        )
        guard isInitialized else { return }
        // Have one waiting, so the next calculation can show it immediately.
        preloadInterstitial()
    }

    /// The session slot, thirty seconds after entering the app. The rating prompt
    /// has first claim on it (`ReviewManager.fireSessionSlot()`); when it passes —
    /// already asked, still inside its own 30-day cooldown — the slot comes here
    /// instead of being wasted. It is also called a full `postReviewGrace` after a
    /// prompt that did fire, which is when that user's first ad is due.
    ///
    /// Deliberately bypasses the action counter and `startupGracePeriod`: those
    /// pace the *repeat* ad, and this one is scheduled explicitly by the timer. Everything that protects the user is
    /// still enforced — the per-session cap, the cooldown between two ads, and
    /// the grace after a rating prompt.
    func showInterstitialAfterFirstAction() {
        guard !isAdFree, !isShowingInterstitial, isInitialized else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        guard interstitialsThisSession < AdConfig.maxInterstitialsPerSession else {
            Self.log.log("first-action interstitial skipped — session cap reached")
            return
        }
        guard Date().timeIntervalSince(lastInterstitialShown) >= AdConfig.interstitialCooldown else {
            Self.log.log("first-action interstitial skipped — cooldown active")
            return
        }
        if let lastReview = ReviewManager.shared.lastReviewRequestedAt,
           Date().timeIntervalSince(lastReview) < AdConfig.postReviewGrace {
            Self.log.log("first-action interstitial skipped — recent rating prompt")
            return
        }

        // Park the counter at the threshold so that if nothing fills in time the
        // next calculation shows the ad, rather than starting again from zero.
        successfulActionsSinceLastInterstitial = AdConfig.successfulActionsRequiredForInterstitial

        if interstitialAd?.isAdReady() == true {
            showInterstitialIfReady()
            return
        }

        // Thirty seconds in, a cold start may still be waiting on its first auction.
        Self.log.log("first-action interstitial — waiting for fill")
        loadInterstitial()
        Task { @MainActor [weak self] in
            let deadline = Date().addingTimeInterval(AdConfig.firstActionAdWaitTimeout)
            while Date() < deadline {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self, !self.isShowingInterstitial else { return }
                guard self.interstitialAd?.isAdReady() == true else { continue }
                guard UIApplication.shared.applicationState == .active else { return }
                self.showInterstitialIfReady()
                return
            }
            Self.log.log("first-action interstitial — no fill in time, deferred to the next action")
        }
    }

    private func showInterstitialIfReady() {
        guard let ad = interstitialAd, ad.isAdReady() else {
            // No fill yet. The counter stays at the threshold, so the next key
            // action tries again — and request another ad here too, otherwise a
            // failed load leaves the slot empty until the retry task fires.
            Self.log.log("interstitial not ready — requesting another")
            loadInterstitial()
            return
        }
        guard let presenter = topPresentingViewController() else { return }

        isShowingInterstitial = true
        lastInterstitialShown = Date()
        successfulActionsSinceLastInterstitial = 0
        interstitialsThisSession += 1
        Self.log.log("showing interstitial (\(self.interstitialsThisSession)/\(AdConfig.maxInterstitialsPerSession) this session)")
        // nil = the ad unit's default placement; `placementName` refers to the
        // dashboard's Placements, which is a different concept from the ad unit ID.
        ad.showAd(viewController: presenter, placementName: nil)
    }

    private func topPresentingViewController() -> UIViewController? {
        guard let root = bannerRootViewController() else { return nil }
        return topmostVC(root)
    }

    private func topmostVC(_ vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController, !presented.isBeingDismissed {
            return topmostVC(presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topmostVC(visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topmostVC(selected)
        }
        return vc
    }

    // MARK: - Rewarded

    func preloadRewarded() {
        guard isInitialized else { return }
        loadRewarded()
    }

    private func loadRewarded() {
        // Deliberately not gated on `isAdFree`: someone inside the free hour may
        // still watch another video to extend it.
        guard !isPremium else { return }
        rewardedRetryTask?.cancel()
        let delegate = RewardedAdDelegate()
        let ad = LPMRewardedAd(adUnitId: AdConfig.rewardedID)
        ad.setDelegate(delegate)
        rewardedDelegate = delegate
        rewardedAd = ad
        isRewardedReady = false
        Self.log.log("requesting rewarded load")
        ad.loadAd()
    }

    /// Shows the rewarded video. Returns false when there is nothing to show, so
    /// the caller can tell the user instead of leaving the tap looking ignored.
    @discardableResult
    func showRewarded() -> Bool {
        guard let ad = rewardedAd, ad.isAdReady(),
              let presenter = topPresentingViewController() else { return false }
        Self.log.log("showing rewarded")
        ad.showAd(viewController: presenter, placementName: nil)
        return true
    }

    /// Shows the rewarded video, fetching one on demand when nothing is cached.
    /// The offer is always on screen, so a tap has to be able to go and get an ad
    /// rather than depend on one happening to be preloaded. Returns false when
    /// nothing could be shown within `timeout`.
    func showRewardedFetchingIfNeeded(timeout: TimeInterval = 6) async -> Bool {
        if showRewarded() { return true }
        preloadRewarded()
        let deadline = Date().addingTimeInterval(timeout)
        while !isRewardedReady, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return showRewarded()
    }

    private func scheduleRewardedRetry() {
        rewardedRetryTask?.cancel()
        rewardedRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.rewardedRetryDelay))
            guard !Task.isCancelled else { return }
            self?.loadRewarded()
        }
    }

    // MARK: - Ad-free window

    /// Grants the reward. Watching again before the window closes extends it from
    /// the current expiry, so the user never loses time they already earned.
    private func grantAdFreeWindow() {
        let base = max(Date(), adFreeUntil ?? .distantPast)
        let until = base.addingTimeInterval(AdConfig.rewardedAdFreeDuration)
        adFreeUntil = until
        UserDefaults.standard.set(until, forKey: Self.adFreeUntilKey)
        Self.log.log("ad-free window granted until \(until, privacy: .public)")
        scheduleAdFreeExpiry()
    }

    /// Re-checks the window against the wall clock. `isAdFree` is always computed
    /// from the stored date so it cannot go stale, but the expiry task does not
    /// fire while the app is suspended — call this on foregrounding so the banner
    /// comes back the moment the hour is actually over.
    func refreshAdFreeState() {
        guard let until = adFreeUntil else { return }
        if until <= Date() {
            endAdFreeWindow()
        } else {
            scheduleAdFreeExpiry()
        }
    }

    private func scheduleAdFreeExpiry() {
        adFreeExpiryTask?.cancel()
        guard let until = adFreeUntil else { return }
        let remaining = until.timeIntervalSinceNow
        guard remaining > 0 else { endAdFreeWindow(); return }
        adFreeExpiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.endAdFreeWindow()
        }
    }

    private func endAdFreeWindow() {
        adFreeExpiryTask?.cancel()
        adFreeExpiryTask = nil
        adFreeUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.adFreeUntilKey)
        Self.log.log("ad-free window ended — resuming ads")
        preloadInterstitial()
    }

    // MARK: - Rewarded callbacks (from RewardedAdDelegate)

    fileprivate func rewardedDidLoad(_ adInfo: LPMAdInfo) {
        isRewardedReady = true
        Self.log.log("rewarded loaded — network: \(adInfo.adNetwork ?? "?", privacy: .public) revenue: \(adInfo.revenue.doubleValue)")
    }

    fileprivate func rewardedDidFailToLoad(_ error: Error) {
        isRewardedReady = false
        Self.log.error("rewarded failed to load: \(error.localizedDescription, privacy: .public)")
        scheduleRewardedRetry()
    }

    fileprivate func rewardedDidFailToDisplay(_ error: Error) {
        isRewardedReady = false
        Self.log.error("rewarded failed to display: \(error.localizedDescription, privacy: .public)")
        loadRewarded()
    }

    fileprivate func rewardedDidReward(_ reward: LPMReward) {
        Self.log.log("reward granted: \(reward.name, privacy: .public) x\(reward.amount)")
        grantAdFreeWindow()
    }

    fileprivate func rewardedDidClose() {
        isRewardedReady = false
        loadRewarded()
    }

    private static let rewardedRetryDelay: TimeInterval = 60

    private func scheduleInterstitialRetry() {
        interstitialRetryTask?.cancel()
        let delay = interstitialRetryDelay
        interstitialRetryDelay = min(interstitialRetryDelay * 2, AdConfig.interstitialMaxRetryDelay)
        Self.log.log("interstitial retry in \(Int(delay))s")
        interstitialRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.isShowingInterstitial else { return }
            self.loadInterstitial()
        }
    }
}

// MARK: - LPMImpressionDataDelegate

/// One log line per actual impression, across every ad format, straight from
/// LevelPlay's own auction record — the authoritative "who won and what the
/// auction looked like" signal, distinct from the per-format `didLoadAd` logs
/// (which fire when an ad is ready, not when it's actually shown). This is
/// also the only place that reports network-specific detail for a live win, so
/// it doubles as manual proof of which networks are actually being served
/// rather than just initialized. The SDK does not expose which networks were
/// merely asked and didn't win — that breakdown only exists in the LevelPlay
/// dashboard's per-ad-unit bidding report (Mediation → the network table).
extension AdsManager: LPMImpressionDataDelegate {
    nonisolated func impressionDataDidSucceed(_ impressionData: LPMImpressionData) {
        Task { @MainActor in
            Self.log.log("auction won — format: \(impressionData.adFormat ?? "?", privacy: .public) network: \(impressionData.adNetwork ?? "?", privacy: .public) instance: \(impressionData.instanceName ?? "?", privacy: .public) revenue: \(impressionData.revenue?.doubleValue ?? 0) precision: \(impressionData.precision ?? "?", privacy: .public) auctionId: \(impressionData.auctionId ?? "?", privacy: .public)")
        }
    }
}

// MARK: - LPMInterstitialAdDelegate

extension AdsManager: LPMInterstitialAdDelegate {
    nonisolated func didLoadAd(with adInfo: LPMAdInfo) {
        Task { @MainActor in
            self.isInterstitialReady = true
            self.interstitialLoadInFlight = false
            self.interstitialRetryDelay = AdConfig.interstitialBaseRetryDelay
            Self.log.log("interstitial loaded — network: \(adInfo.adNetwork ?? "?", privacy: .public) revenue: \(adInfo.revenue.doubleValue)")
        }
    }

    nonisolated func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        Task { @MainActor in
            self.isInterstitialReady = false
            self.interstitialLoadInFlight = false
            Self.log.error("interstitial failed to load: \(error.localizedDescription, privacy: .public)")
            self.scheduleInterstitialRetry()
        }
    }

    nonisolated func didDisplayAd(with adInfo: LPMAdInfo) {}

    nonisolated func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        Task { @MainActor in
            Self.log.error("interstitial failed to display: \(error.localizedDescription, privacy: .public)")
            self.isShowingInterstitial = false
            self.isInterstitialReady = false
            // The ad never reached the user, so don't charge them for it: undo the
            // cooldown and the session tally, and put the counter back at the
            // threshold so the next key action can try again straight away.
            self.lastInterstitialShown = .distantPast
            self.interstitialsThisSession = max(0, self.interstitialsThisSession - 1)
            self.successfulActionsSinceLastInterstitial = AdConfig.successfulActionsRequiredForInterstitial
            self.loadInterstitial()
        }
    }

    nonisolated func didClickAd(with adInfo: LPMAdInfo) {}

    nonisolated func didCloseAd(with adInfo: LPMAdInfo) {
        Task { @MainActor in
            self.isShowingInterstitial = false
            self.isInterstitialReady = false
            self.lastInterstitialClosedAt = Date()
            Self.log.log("interstitial closed — reloading")
            self.loadInterstitial()
        }
    }

    nonisolated func didChangeAdInfo(_ adInfo: LPMAdInfo) {}
}

// MARK: - LPMRewardedAdDelegate

/// `LPMInterstitialAdDelegate` and `LPMRewardedAdDelegate` declare the same
/// selectors (`didLoadAdWithAdInfo:` and friends), so one object cannot tell the
/// two formats apart. The rewarded callbacks get their own delegate, which
/// forwards to `AdsManager`.
private final class RewardedAdDelegate: NSObject, LPMRewardedAdDelegate {
    func didLoadAd(with adInfo: LPMAdInfo) {
        Task { @MainActor in AdsManager.shared.rewardedDidLoad(adInfo) }
    }

    func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        Task { @MainActor in AdsManager.shared.rewardedDidFailToLoad(error) }
    }

    func didDisplayAd(with adInfo: LPMAdInfo) {}

    func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        Task { @MainActor in AdsManager.shared.rewardedDidFailToDisplay(error) }
    }

    func didRewardAd(with adInfo: LPMAdInfo, reward: LPMReward) {
        Task { @MainActor in AdsManager.shared.rewardedDidReward(reward) }
    }

    func didClickAd(with adInfo: LPMAdInfo) {}

    func didCloseAd(with adInfo: LPMAdInfo) {
        Task { @MainActor in AdsManager.shared.rewardedDidClose() }
    }

    func didChangeAdInfo(_ adInfo: LPMAdInfo) {}
}

#else

// MARK: - No-op stub (IronSource not linked)

@MainActor
final class AdsManager: ObservableObject {
    static let shared = AdsManager()
    @Published private(set) var isInitialized = false
    @Published private(set) var adFreeUntil: Date?
    @Published private(set) var isRewardedReady = false
    var isAdFree: Bool { true }
    private(set) var lastInterstitialClosedAt: Date?
    private init() {}
    func start() {}
    func preloadInterstitial() {}
    func preloadRewarded() {}
    func noteNewSession() {}
    func registerKeyAction() {}
    func showInterstitialAfterFirstAction() {}
    func registerSecondaryAction() {}
    @discardableResult func showRewarded() -> Bool { false }
    func showRewardedFetchingIfNeeded(timeout: TimeInterval = 6) async -> Bool { false }
    func refreshAdFreeState() {}
    func bannerRootViewController() -> UIViewController? { nil }
}

#endif
