//
//  RewardedPrompt.swift
//  amortix
//
//  Entry point for the rewarded video: watch one, get an hour without ads.
//  It sits directly above the banner, so the offer appears next to the very thing
//  it removes.
//

import SwiftUI

struct RewardedPrompt: View {
    @ObservedObject private var ads = AdsManager.shared
    @AppStorage("isPremiumUnlocked") private var isPremium = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showUnavailable = false
    @State private var isFetching = false

    var body: some View {
        Group {
            if isPremium {
                EmptyView()
            } else if !ads.isInitialized {
                // No SDK yet — still starting, or no consent to request ads. An
                // offer that can only ever answer "no video available" is noise.
                EmptyView()
            } else if let until = ads.adFreeUntil, until > Date() {
                activeCard(until: until)
            } else {
                // Always offered, even with nothing preloaded: fill is unreliable,
                // and an entry point that only appears when an ad happens to be
                // cached is one nobody ever sees.
                offerButton
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { ads.refreshAdFreeState() }
        }
        .alert("rewarded_unavailable_title", isPresented: $showUnavailable) {
            Button("general_ok", role: .cancel) {}
        } message: {
            Text("rewarded_unavailable_message")
        }
    }

    private var offerButton: some View {
        Button {
            guard !isFetching else { return }
            isFetching = true
            Task {
                let shown = await ads.showRewardedFetchingIfNeeded()
                isFetching = false
                if !shown { showUnavailable = true }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                Text("rewarded_watch")
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if isFetching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.brandBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandBlue.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func activeCard(until: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
            Text("rewarded_active")
                .fontWeight(.semibold)
            Spacer(minLength: 0)
            Text(until, style: .relative)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .foregroundStyle(Color.brandGreen)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.brandGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandGreen.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}
