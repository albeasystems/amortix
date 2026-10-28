import XCTest

/// Drives the happy path (advanced mixed mortgage -> results -> chart -> amortization table) in every app
/// language and writes the screenshots to marketing/source/<lang>/. Not part of the normal test run:
/// it only does anything when MARKETING_OUT is set (see marketing/capture.sh).
final class MarketingCaptures: XCTestCase {

    // app language code, simulator locale, value of the in-app "selectedCountry" setting
    private let languages: [(String, String, String)] = [
        ("es", "es_ES", "es"), ("en", "en_US", "en"), ("fr", "fr_FR", "fr"), ("de", "de_DE", "de"),
        ("it", "it_IT", "it"), ("pt", "pt_BR", "pt-BR"), ("hi", "hi_IN", "hi"), ("ar", "ar_SA", "ar"),
        ("zh", "zh_CN", "es"),
    ]

    private func shot(_ name: String, lang: String, out: String) {
        let dir = "\(out)/\(lang)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    @MainActor
    func testCaptureAllLanguages() throws {
        guard let out = ProcessInfo.processInfo.environment["MARKETING_OUT"] ?? UserDefaults.standard.string(forKey: "MARKETING_OUT"),
              !out.isEmpty else { throw XCTSkip("MARKETING_OUT not set") }
        let only = ProcessInfo.processInfo.environment["MARKETING_LANGS"]?.split(separator: ",").map(String.init)

        for (lang, locale, country) in languages where only == nil || only!.contains(lang) {
            let app = XCUIApplication()
            let tag = lang == "zh" ? "zh-Hans" : lang
            app.launchArguments = ["-AppleLanguages", "(\(tag))", "-AppleLocale", locale,
                                   "-selectedCountry", country, "-isPremiumUnlocked", "YES", "-amortix_review_rated_manually", "YES", "-amortix_review_last_request_ts", "4102444800"]
            app.launch()
            sleep(3)
            let rtl = lang == "ar"
            func at(_ x: Double, _ y: Double) -> XCUICoordinate {
                app.coordinate(withNormalizedOffset: CGVector(dx: rtl ? 1 - x / 440 : x / 440, dy: y / 956))
            }
            func drag(_ y1: Double, _ y2: Double) {
                let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y1 / 956))
                let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y2 / 956))
                a.press(forDuration: 0.05, thenDragTo: b)
            }

            at(344, 581).tap()                       // Mixed
            sleep(1)
            for _ in 0..<5 { at(380, 407).tap() }    // 25 -> 30 years
            sleep(2)
            shot("01-inputs", lang: lang, out: out)
            drag(700, 250)                           // reveal fixed period, index, spread
            sleep(1)
            shot("02-advanced", lang: lang, out: out)
            at(220, 839).tap()                       // Calculate
            sleep(2)
            for _ in 0..<3 { drag(760, 200) }        // to the bottom
            sleep(1)
            shot("04-chart", lang: lang, out: out)
            drag(300, 620)                           // back up to the payments
            sleep(1)
            shot("03-results", lang: lang, out: out)
            for _ in 0..<3 { drag(760, 200) }
            sleep(1)
            at(220, 763).tap()                       // View amortization table
            sleep(2)
            shot("05-table", lang: lang, out: out)
            app.terminate()
        }
    }
}
