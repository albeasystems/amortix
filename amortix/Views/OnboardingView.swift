import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [(title: String, subtitle: String, symbol: String, color: Color)] = [
        ("onboarding_page1_title", "onboarding_page1_subtitle", "house.fill",                 .brandBlue),
        ("onboarding_page2_title", "onboarding_page2_subtitle", "arrow.counterclockwise",     .brandTeal),
        ("onboarding_page3_title", "onboarding_page3_subtitle", "chart.line.uptrend.xyaxis",  .brandOrange),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(
                        titleKey:    LocalizedStringKey(pages[i].title),
                        subtitleKey: LocalizedStringKey(pages[i].subtitle),
                        symbol:      pages[i].symbol,
                        color:       pages[i].color
                    )
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()

            // Skip
            if currentPage < pages.count - 1 {
                HStack {
                    Spacer()
                    Button(LocalizedStringKey("onboarding_skip"), action: finish)
                        .font(.subheadline)
                        .padding()
                }
            }
        }
        .overlay(alignment: .bottom) {
            Button(action: advance) {
                Text(LocalizedStringKey(currentPage == pages.count - 1
                    ? "onboarding_start"
                    : "onboarding_next"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}

private struct OnboardingPageView: View {
    let titleKey:    LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let symbol:      String
    let color:       Color

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(color)
                .padding(36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(spacing: 12) {
                Text(titleKey)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(subtitleKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
