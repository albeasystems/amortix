import Foundation
import StoreKit
import Combine

/// Wraps StoreKit 2 for the single non-consumable "Remove ads" purchase.
///
/// - Loads the product at launch so price is ready when Settings opens.
/// - Listens to `Transaction.updates` for purchases made on other devices / refunds.
/// - Flips `isPremiumUnlocked` in `UserDefaults`, which `@AppStorage` views observe.
@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    static let removeAdsProductID = "com.albeasystems.amortix.premium"
    private static let entitlementKey = "isPremiumUnlocked"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Public

    var localizedPrice: String? { product?.displayPrice }

    /// Re-fetch the product from the App Store. Idempotent.
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            product = products.first
#if DEBUG
            if product == nil {
                print("[Store] Product \(Self.removeAdsProductID) not returned by App Store — " +
                      "either it isn't approved yet, the bundle ID doesn't match, or the device " +
                      "isn't signed into a Sandbox/TestFlight account.")
            }
#endif
        } catch {
            lastError = error.localizedDescription
#if DEBUG
            print("[Store] loadProducts failed: \(error)")
#endif
        }
    }

    /// Trigger the purchase sheet. Returns true on completed verified purchase.
    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProducts() }
        guard let product else {
            lastError = "Product unavailable"
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Transaction not verified by App Store"
                    return false
                }
                unlock()
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                // Awaiting parental approval / SCA — entitlement will arrive via Transaction.updates.
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Forces App Store to refresh receipts; useful after reinstall or device change.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func unlock() {
        UserDefaults.standard.set(true, forKey: Self.entitlementKey)
    }

    private func lock() {
        UserDefaults.standard.set(false, forKey: Self.entitlementKey)
    }

    /// Walks current entitlements once. Used at launch and after explicit restore.
    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        if entitled { unlock() }
        // We don't auto-lock here — the easter-egg toggle in SettingsViewModel
        // also writes to this key, and at first launch with no entitlement we
        // shouldn't overwrite an existing local state.
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.removeAdsProductID {
            if transaction.revocationDate == nil {
                unlock()
            } else {
                // Refunded / family-shared revoked.
                lock()
            }
        }
        await transaction.finish()
    }
}
