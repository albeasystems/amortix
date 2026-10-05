//
//  ConsentService.swift
//  amortix
//
//  Google User Messaging Platform (UMP) — a Google-certified CMP. Publishers
//  serving ads to EEA/UK users must gather consent through one, otherwise AdMob
//  returns no fill for that traffic.
//
//  Call order: `resolve()` must complete before `AdsManager.start()`, so the
//  mediation SDK initialises with a consent state already on record — and
//  `AdsManager.start()` refuses to run unless `canRequestAds` is true. Outside
//  the EEA/UK the CMP reports "not required" and `resolve()` returns without
//  showing anything, so the flow costs users elsewhere nothing.
//
//  Compiles to a permissive stub when the pod is not linked.
//

import Foundation
import UIKit
import os

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform

@MainActor
final class ConsentService {
    static let shared = ConsentService()
    private init() {}

    private static let log = Logger(subsystem: "com.albeasystems.amortix", category: "consent")

    /// How long to keep waiting for the user to answer the form. Ads stay off
    /// until they do, so this is generous: the form is modal, and someone who
    /// takes a few minutes to read it should still get ads once they choose,
    /// not lose them for the whole session. The bound only stops the poll from
    /// living forever on a phone left with the form open.
    private static let decisionTimeout: TimeInterval = 30 * 60
    /// How long to wait for a window to exist to present the form from.
    private static let presenterTimeout: TimeInterval = 5

    /// Whether the CMP has cleared the app to request ads. Also true where no
    /// consent is required at all (most of the world).
    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    /// True only where the user must be offered a way to revisit their choice —
    /// Settings shows a "Privacy options" row in that case.
    var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Refreshes consent status and presents the CMP form when the user's region
    /// requires it. If ATT was denied, skips the form to avoid asking the user
    /// twice about tracking. Returns once the flow has settled, whatever the
    /// outcome — a CMP failure must not block the app, it only means ads may
    /// not serve.
    func resolve() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    Self.log.error("consent info update failed: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }

        // If ATT was denied, skip the CMP form. The user made a tracking choice
        // in ATT already, and showing another form asking to track again violates
        // Guideline 5.1.1(iv) — the app must not pester them about the same
        // decision. Treat this as "user declined to track" for ad purposes.
        if !TrackingService.isAuthorized {
            Self.log.log("ATT was denied — skipping CMP form (user already declined tracking)")
            return
        }

        // Whether a form is actually going to be put in front of the user. Read
        // before presenting, because presenting is what changes it.
        let expectsForm = ConsentInformation.shared.consentStatus == .required
            && ConsentInformation.shared.formStatus == .available
        Self.log.log("consent info — status: \(ConsentInformation.shared.consentStatus.rawValue) form: \(ConsentInformation.shared.formStatus.rawValue) (status 1 = required, form 1 = available)")

        await presentFormIfRequired()
        if expectsForm { await waitForDecision() }

        Self.log.log("consent resolved — canRequestAds: \(self.canRequestAds)")
    }

    private func presentFormIfRequired() async {
        guard let presenter = await waitForPresenter() else {
            Self.log.error("no view controller to present the consent form from")
            return
        }
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: presenter) { error in
                if let error {
                    Self.log.error("consent form failed: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }
    }

    /// UMP has been observed calling `loadAndPresentIfRequired`'s completion about
    /// a second after the form appears, while it is still on screen and untouched,
    /// which let the ads SDK initialise and fire its first request before the user
    /// had chosen. Only the consent status itself is trustworthy, so wait for it to
    /// leave `.required`. Nothing but the ads waits on this, and they must not
    /// start without an answer, so there is no "start anyway" fallback.
    private func waitForDecision() async {
        let deadline = Date().addingTimeInterval(Self.decisionTimeout)
        while ConsentInformation.shared.consentStatus == .required, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
        }
        if ConsentInformation.shared.consentStatus == .required {
            Self.log.error("consent form still unanswered after \(Int(Self.decisionTimeout))s — ads stay off this session")
        }
    }

    /// The `.task` that drives this can run before any window has a root view
    /// controller, and the ATT alert that precedes it may still be dismissing.
    /// Returning nil there silently skips the whole CMP flow.
    private func waitForPresenter() async -> UIViewController? {
        let deadline = Date().addingTimeInterval(Self.presenterTimeout)
        while Date() < deadline {
            if let vc = topViewController() { return vc }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    /// Re-opens the CMP so the user can change a choice they already made.
    func presentPrivacyOptions() {
        guard let presenter = topViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: presenter) { error in
            if let error {
                Self.log.error("privacy options form failed: \(error.localizedDescription, privacy: .public)")
            }
            // If ads were held back for lack of consent and this answer now
            // allows them, start them; `start()` is idempotent and re-checks.
            Task { @MainActor in AdsManager.shared.start() }
        }
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene?.windows.first?.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

#else

// MARK: - No-op stub (UserMessagingPlatform not linked)

@MainActor
final class ConsentService {
    static let shared = ConsentService()
    private init() {}
    var canRequestAds: Bool { true }
    var isPrivacyOptionsRequired: Bool { false }
    func resolve() async {}
    func presentPrivacyOptions() {}
}

#endif
