import SwiftUI

struct MainTabView: View {
    @AppStorage("selectedCountry") private var selectedCountry: String = CountryMarket.spain.rawValue

    @State private var showSettings    = false
    @State private var mortgageSegment = 0   // 0=Calculadora  1=Revisión tipo  2=Estrés
    @State private var amortSegment    = 0   // 0=Amortización parcial  1=Cuota extra

    @StateObject private var mortgageVM = MortgageViewModel()
    @StateObject private var partialVM  = PartialAmortizationViewModel()
    @StateObject private var euriborVM  = EuriborViewModel()
    @StateObject private var extraVM    = ExtraPaymentsViewModel()
    @StateObject private var settingsVM = SettingsViewModel()

    private var country: CountryMarket {
        CountryMarket(rawValue: selectedCountry) ?? .spain
    }

    private var mortgageLabels: [String] {
        country.usesEuribor
            ? ["tab_calculator", "tab_rate_review", "tab_stress"]
            : ["tab_calculator", "tab_stress"]
    }

    var body: some View {
        TabView {

            // MARK: - Tab 1: Hipoteca
            NavigationStack {
                VStack(spacing: 0) {
                    segmentedPicker(selection: $mortgageSegment, labels: mortgageLabels)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    Divider()

                    Group {
                        if mortgageSegment == 0 {
                            MortgageCalculatorView().transition(.opacity)
                        } else if mortgageSegment == 1 && country.usesEuribor {
                            EuriborReviewView().transition(.opacity)
                        } else {
                            StressTestView().transition(.opacity)
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
                .animation(.easeInOut(duration: 0.2), value: mortgageSegment)
                .navigationTitle(tabTitle(for: mortgageSegment, keys: mortgageLabels))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { settingsButton }
                    ToolbarItem(placement: .topBarTrailing) { EmptyView() }
                }
                // The offer sits directly above the banner, next to the very
                // thing it removes. Only on this tab, so it is one offer per
                // session rather than one per screen.
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        RewardedPrompt()
                        FreeBanner(placement: .mortgage)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .environmentObject(mortgageVM)
            .environmentObject(euriborVM)
            .tabItem { Label("tab_mortgage_tab", systemImage: "house") }

            // MARK: - Tab 2: Amortización (2 segments — Invest removed)
            NavigationStack {
                VStack(spacing: 0) {
                    segmentedPicker(
                        selection: $amortSegment,
                        labels: ["tab_amortize", "tab_extra_monthly"]
                    )
                    .padding(.horizontal)
                    .padding(.top, 4)
                    Divider()

                    switch amortSegment {
                    case 1:  ExtraPaymentsView().transition(.opacity)
                    default: PartialAmortizationView().transition(.opacity)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .animation(.easeInOut(duration: 0.2), value: amortSegment)
                .navigationTitle(tabTitle(for: amortSegment,
                                          keys: ["tab_amortize", "tab_extra_monthly"]))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { settingsButton }
                    ToolbarItem(placement: .topBarTrailing) { EmptyView() }
                }
                .safeAreaInset(edge: .bottom) { FreeBanner(placement: .amortization) }
            }
            .environmentObject(partialVM)
            .environmentObject(euriborVM)
            .environmentObject(extraVM)
            .tabItem { Label("tab_amortize_tab", systemImage: "arrow.counterclockwise") }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView().environmentObject(settingsVM)
            }
        }
        .onChange(of: selectedCountry) { v in
            syncCountry(v)
            if let c = CountryMarket(rawValue: v), !c.usesEuribor, mortgageSegment == 1 {
                mortgageSegment = 0
            }
        }
        // ATT is requested by `AmortixApp`'s startup sequence, which has to run
        // it *before* the CMP and the ads SDK init — see the comment there.
        .onAppear { syncCountry(selectedCountry) }
    }

    // MARK: - Helpers

    private func syncCountry(_ raw: String) {
        guard let c = CountryMarket(rawValue: raw) else { return }
        mortgageVM.country = c
        partialVM.country  = c
        extraVM.country    = c
        euriborVM.country  = c
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
    }

    /// Country menu — shows flag + name + currency so the user understands what they're selecting.
    private var countryMenuButton: some View {
        let current = CountryMarket(rawValue: selectedCountry) ?? .spain
        return Menu {
            Section {
                Picker("", selection: Binding(
                    get: { current },
                    set: { selectedCountry = $0.rawValue }
                )) {
                    ForEach(CountryMarket.allCases) { c in
                        // Menu Picker only renders a single Text per row —
                        // concatenate everything into one label.
                        Text("\(c.flagEmoji)  \(c.displayName)  ·  \(c.currencyCode)")
                            .tag(c)
                    }
                }
            } header: {
                Text("country_menu_header")
            } footer: {
                Text("country_menu_footer")
            }
        } label: {
            HStack(spacing: 4) {
                Text(current.flagEmoji)
                    .font(.title3)
                Text(current.currencyCode)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func segmentedPicker(selection: Binding<Int>, labels: [String]) -> some View {
        Picker("", selection: selection) {
            ForEach(labels.indices, id: \.self) { i in
                Text(LocalizedStringKey(labels[i])).tag(i)
            }
        }
        .pickerStyle(.segmented)
    }

    private func tabTitle(for index: Int, keys: [String]) -> LocalizedStringKey {
        LocalizedStringKey(keys.indices.contains(index) ? keys[index] : keys[0])
    }
}

#Preview { MainTabView() }
