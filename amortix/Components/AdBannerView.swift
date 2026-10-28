//
//  AdBannerView.swift
//  amortix
//
//  Unity LevelPlay banner (LPMBannerAdView, a UIView subclass) wrapped in
//  UIViewRepresentable. Waits for SDK init and a real UIWindow before loading,
//  retries with backoff. Compiles to an EmptyView stub when IronSource is not linked.
//

import SwiftUI

#if canImport(IronSource)
import IronSource
import UIKit
import os

struct AdBannerView: UIViewRepresentable {
    let placementID: String

    func makeCoordinator() -> Coordinator { Coordinator(placementID: placementID) }

    func makeUIView(context: Context) -> LPMBannerAdView {
        let config = LPMBannerAdViewConfigBuilder()
            .set(adSize: LPMAdSize.banner())
            .build()
        let banner = LPMBannerAdView(adUnitId: placementID, config: config)
        // Until an ad fills, the view paints its own opaque background, which
        // shows up as a solid 50pt slab across the bottom of the screen. Clear
        // keeps the reserved space invisible whenever there is nothing to show.
        banner.backgroundColor = .clear
        banner.setDelegate(context.coordinator)
        context.coordinator.banner = banner
        return banner
    }

    func updateUIView(_ uiView: LPMBannerAdView, context: Context) {
        context.coordinator.loadIfPossible()
    }

    static func dismantleUIView(_ uiView: LPMBannerAdView, coordinator: Coordinator) {
        coordinator.cancelRetry()
        uiView.destroy()
    }

    @MainActor
    final class Coordinator: NSObject, LPMBannerAdViewDelegate {
        weak var banner: LPMBannerAdView?
        let placementID: String
        private var hasLoaded = false
        private var retryAttempt = 0
        private var retryTask: Task<Void, Never>?
        private static let maxRetryDelay: TimeInterval = 30
        private static let recheckInterval: TimeInterval = 0.5
        private static let log = Logger(subsystem: "com.albeasystems.amortix", category: "ads-banner")

        init(placementID: String) { self.placementID = placementID }

        func loadIfPossible() {
            guard !hasLoaded, let banner else { return }
            guard AdsManager.shared.isInitialized,
                  let vc = AdsManager.shared.bannerRootViewController(),
                  banner.window != nil else {
                scheduleRecheck()
                return
            }
            cancelRetry()
            hasLoaded = true
            Self.log.log("requesting banner load")
            banner.loadAd(with: vc)
        }

        /// Preconditions not met yet (SDK still initialising, or the view has no
        /// window). Nothing was asked of the network, so this polls at a fixed
        /// short interval — backing off here would leave the banner blank for
        /// tens of seconds after the SDK is ready.
        private func scheduleRecheck() {
            cancelRetry()
            retryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(Self.recheckInterval))
                guard !Task.isCancelled else { return }
                self?.loadIfPossible()
            }
        }

        /// A load actually failed, so back off exponentially before asking again.
        private func scheduleRetry() {
            cancelRetry()
            let delay = min(pow(2.0, Double(retryAttempt)), Self.maxRetryDelay)
            retryAttempt += 1
            retryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.loadIfPossible()
            }
        }

        func cancelRetry() {
            retryTask?.cancel()
            retryTask = nil
        }

        // MARK: LPMBannerAdViewDelegate

        nonisolated func didLoadAd(with adInfo: LPMAdInfo) {
            Task { @MainActor in
                Self.log.log("banner loaded — network: \(adInfo.adNetwork ?? "?", privacy: .public) revenue: \(adInfo.revenue.doubleValue)")
            }
        }

        nonisolated func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
            Task { @MainActor in
                Self.log.error("banner failed: \(error.localizedDescription, privacy: .public)")
                self.hasLoaded = false
                self.scheduleRetry()
            }
        }

        nonisolated func didClickAd(with adInfo: LPMAdInfo) {}
        nonisolated func didDisplayAd(with adInfo: LPMAdInfo) {}
        nonisolated func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {}
        nonisolated func didLeaveApp(with adInfo: LPMAdInfo) {}
        nonisolated func didExpandAd(with adInfo: LPMAdInfo) {}
        nonisolated func didCollapseAd(with adInfo: LPMAdInfo) {}
    }
}

#else

struct AdBannerView: View {
    let placementID: String
    var body: some View { EmptyView() }
}

#endif

/// Banner that shows only for free users and reserves the standard 50pt height.
/// Hidden for premium buyers, during the ad-free hour earned from a rewarded
/// video, and while the SDK is not running (still starting, or no consent to
/// request ads) — it reclaims its 50pt whenever it is hidden.
struct FreeBanner: View {
    let placement: AdConfig.Placement
    @ObservedObject private var ads = AdsManager.shared
    // Observed directly, not just via `ads.isAdFree`: a purchase flips this flag
    // in UserDefaults through StoreService, and `isAdFree` is a plain computed
    // property with nothing `@Published` behind it, so the view would never be
    // told to re-render and the banner would linger until the next relaunch.
    @AppStorage("isPremiumUnlocked") private var isPremium = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !isPremium, !ads.isAdFree, ads.isInitialized {
                AdBannerView(placementID: AdConfig.bannerID(placement))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
            }
        }
        // The expiry timer does not fire while the app is suspended, so the hour
        // may well be over by the time the user comes back.
        .onChange(of: scenePhase) { phase in
            if phase == .active { ads.refreshAdFreeState() }
        }
    }
}
