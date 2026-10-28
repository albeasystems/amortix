import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: SettingsViewModel
    @AppStorage("isPremiumUnlocked")  private var isPremiumUnlocked = false
    @AppStorage("selectedCountry")    private var selectedCountry: String = CountryMarket.spain.rawValue
    @AppStorage("amortizationSystem") private var amortizationSystem = AmortizationSystem.french.rawValue
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var store = StoreService.shared
    @State private var purchaseAlert: PurchaseAlert?
    @State private var showSystems = false
    /// Only true where the user's region required a consent form, so the CMP
    /// entry point stays hidden everywhere else.
    @State private var showPrivacyOptions = false
    @Environment(\.openURL) private var openURL

    private enum PurchaseAlert: Identifiable {
        case success, restored, restoredEmpty, error(String)
        var id: String {
            switch self {
            case .success: return "success"
            case .restored: return "restored"
            case .restoredEmpty: return "restoredEmpty"
            case .error(let msg): return "error_\(msg)"
            }
        }
    }

    var body: some View {
        Form {

            // MARK: - Premium / Remove ads
            Section {
                if isPremiumUnlocked {
                    HStack {
                        rowIcon("star.fill", color: .brandOrange)
                        Text("settings_premium_active")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandOrange)
                        Spacer()
                        Text("general_premium_badge")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.brandOrange.opacity(0.15))
                            .foregroundStyle(Color.brandOrange)
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        Task { await runPurchase() }
                    } label: {
                        HStack {
                            rowIcon("nosign", color: .brandRed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings_remove_ads")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.brandBlue)
                                Text("settings_remove_ads_subtitle")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandBlue.opacity(0.6))
                            }
                            Spacer()
                            if store.isPurchasing {
                                ProgressView().controlSize(.small)
                            } else if let price = store.localizedPrice {
                                Text(price)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.brandBlue)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.brandBlue.opacity(0.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPurchasing)

                    Button {
                        Task { await runRestore() }
                    } label: {
                        HStack {
                            rowIcon("arrow.clockwise", color: .brandTeal)
                            Text("settings_restore_purchases")
                                .foregroundStyle(Color.brandBlue)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPurchasing)
                }
            }

            // MARK: - Preferences (Language, Country)
            Section {
                Picker(selection: Binding(
                    get: { vm.selectedAppLanguage },
                    set: { vm.selectedAppLanguage = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                } label: {
                    HStack {
                        rowIcon("globe", color: .brandBlue)
                        Text("settings_language").foregroundStyle(Color.brandBlue)
                    }
                }

                Picker(selection: Binding(
                    get: { CountryMarket(rawValue: selectedCountry) ?? .spain },
                    set: { selectedCountry = $0.rawValue }
                )) {
                    ForEach(CountryMarket.allCases) { c in
                        // A menu Picker only renders a single Text per row, so the
                        // flag, name and currency have to be one concatenated label
                        // (same approach as the country menu in MainTabView).
                        Text("\(c.flagEmoji)  \(c.displayName)  ·  \(c.currencyCode)")
                            .tag(c)
                    }
                } label: {
                    HStack {
                        rowIcon("map.fill", color: .brandTeal)
                        Text("settings_country").foregroundStyle(Color.brandBlue)
                    }
                }

                if let country = CountryMarket(rawValue: selectedCountry) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(country.lawKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            // MARK: - Amortization system (model)
            Section {
                Picker(selection: $amortizationSystem) {
                    ForEach(AmortizationSystem.allCases) { system in
                        Text(LocalizedStringKey(system.localizedKey)).tag(system.rawValue)
                    }
                } label: {
                    HStack {
                        rowIcon("function", color: .brandBlue)
                        Text("settings_model_title").foregroundStyle(Color.brandBlue)
                    }
                }

                Button { showSystems = true } label: {
                    HStack {
                        rowIcon("questionmark.circle.fill", color: .brandTeal)
                        Text("systems_info_cta").foregroundStyle(Color.brandBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.brandBlue.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("settings_model_header")
            } footer: {
                Text("settings_model_caption")
            }

            // MARK: - Web / Legal / Support
            Section {
                Link(destination: vm.websiteURL) {
                    externalRow(icon: "globe", color: .brandBlue, titleKey: "settings_web_app")
                }
                Link(destination: vm.privacyPolicyURL) {
                    externalRow(icon: "lock.shield.fill", color: .purple, titleKey: "settings_privacy_policy")
                }
                Link(destination: vm.termsOfUseURL) {
                    externalRow(icon: "doc.text.fill", color: .brandOrange, titleKey: "settings_terms_of_use")
                }
                Link(destination: vm.supportURL) {
                    externalRow(icon: "questionmark.circle.fill", color: .brandTeal, titleKey: "settings_support")
                }
                // Google requires an entry point back into the CMP wherever
                // consent was gathered; elsewhere the row stays hidden.
                if showPrivacyOptions {
                    Button {
                        ConsentService.shared.presentPrivacyOptions()
                    } label: {
                        HStack {
                            rowIcon("slider.horizontal.3", color: .purple)
                            Text("settings_privacy_options").foregroundStyle(Color.brandBlue)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // MARK: - Actions
            Section {
                Link(destination: vm.feedbackURL) {
                    externalRow(icon: "envelope.fill", color: .brandOrange, titleKey: "settings_send_feedback")
                }
                // A Button rather than a Link so the trip to the App Store can be
                // recorded. That does not prove they rated, so it only releases
                // the interstitials and applies the normal cooldown — see
                // `ReviewManager.markRatedManually()`.
                Button {
                    ReviewManager.shared.markRatedManually()
                    openURL(vm.rateAppURL)
                } label: {
                    externalRow(icon: "star.fill", color: .yellow, titleKey: "settings_rate_app")
                }
                .buttonStyle(.plain)
                ShareLink(
                    item: vm.appStoreURL,
                    message: Text("settings_share_app_message")
                ) {
                    HStack {
                        rowIcon("square.and.arrow.up", color: .brandGreen)
                        Text("settings_share_app").foregroundStyle(Color.brandBlue)
                        Spacer()
                    }
                }
            }

            // MARK: - Version
            Section {
                HStack {
                    Text("settings_app_version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ZStack {
                        Text(vm.appVersion).foregroundStyle(.secondary)
                        Color.clear
                            .frame(width: 120, height: 44)
                            .contentShape(Rectangle())
                            .opacity(0.001)
                            .onTapGesture { vm.handleSecretTap() }
                    }
                }
            }
        }
        .navigationTitle("settings_nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("general_close") { dismiss() }
            }
        }
        .alert(vm.premiumAlertTitle, isPresented: Binding(
            get: { vm.showPremiumAlert },
            set: { vm.showPremiumAlert = $0 }
        )) {
            Button("premium_alert_ok") {}
        } message: {
            Text(vm.premiumAlertMessage)
        }
        .alert(item: $purchaseAlert) { alert in
            switch alert {
            case .success:
                return Alert(
                    title: Text("premium_unlock_title"),
                    message: Text("premium_unlock_message"),
                    dismissButton: .default(Text("premium_alert_ok"))
                )
            case .restored:
                return Alert(
                    title: Text("settings_restore_success_title"),
                    message: Text("settings_restore_success_message"),
                    dismissButton: .default(Text("premium_alert_ok"))
                )
            case .restoredEmpty:
                return Alert(
                    title: Text("settings_restore_empty_title"),
                    message: Text("settings_restore_empty_message"),
                    dismissButton: .default(Text("premium_alert_ok"))
                )
            case .error(let msg):
                return Alert(
                    title: Text("settings_purchase_error_title"),
                    message: Text(msg),
                    dismissButton: .default(Text("premium_alert_ok"))
                )
            }
        }
        .task {
            // Ensure product is loaded when the user opens Settings — App init
            // also kicks this off, but a slow first network call could leave
            // the price blank until we re-try.
            if store.product == nil { await store.loadProducts() }
            showPrivacyOptions = ConsentService.shared.isPrivacyOptionsRequired
        }
        .sheet(isPresented: $showSystems) {
            LoanSystemsInfoView()
        }
    }

    // MARK: - Actions

    private func runPurchase() async {
        let wasPremium = isPremiumUnlocked
        let ok = await store.purchase()
        if ok && !wasPremium {
            purchaseAlert = .success
            HapticService.premiumToggle()
        } else if let err = store.lastError, !ok {
            purchaseAlert = .error(err)
        }
    }

    private func runRestore() async {
        let wasPremium = isPremiumUnlocked
        await store.restorePurchases()
        if let err = store.lastError {
            purchaseAlert = .error(err)
        } else if isPremiumUnlocked && !wasPremium {
            purchaseAlert = .restored
        } else if !isPremiumUnlocked {
            purchaseAlert = .restoredEmpty
        }
    }

    // MARK: - Row helpers

    private func rowIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, alignment: .center)
    }

    private func externalRow(icon: String, color: Color, titleKey: LocalizedStringKey) -> some View {
        HStack {
            rowIcon(icon, color: color)
            Text(titleKey)
                .foregroundStyle(Color.brandBlue)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.bold())
                .foregroundStyle(Color.brandBlue.opacity(0.5))
        }
    }
}

// MARK: - Amortization systems explainer

/// Sheet explaining the three repayment systems (French / Linear / American).
private struct LoanSystemsInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AmortizationSystem.allCases) { system in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(system.localizedKey))
                            .font(.headline)
                            .foregroundStyle(Color.brandBlue)
                        Text(LocalizedStringKey(system.infoKey))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("systems_info_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("general_close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsViewModel())
    }
}
