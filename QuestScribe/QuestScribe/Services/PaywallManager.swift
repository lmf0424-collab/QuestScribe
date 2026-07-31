import Foundation
import Observation
import StoreKit

// MARK: - Paywall Manager

/// Tracks Pro entitlement: a StoreKit 2 subscription OR a local 7-day free
/// trial. On sideloaded builds StoreKit can't process purchases, so the local
/// trial is what grants access for the first week; on App Store builds the
/// StoreKit transaction takes over.
@Observable
final class PaywallManager {

    /// Must match the subscription group ID in `QuestScribe.storekit` and App Store Connect.
    static let groupID = "21653932"
    /// Must match the product ID in App Store Connect (and the StoreKit config).
    static let monthlyProductID = "com.questscribe.pro.monthly"

    private static let trialStartKey = "questscribe.localTrialStart"

    private var updatesTask: Task<Void, Never>?
    private var activeSubscription = false

    /// Debug-only override, toggled from Settings in DEBUG builds.
    var debugUnlocked = false

    // MARK: Trial (local fallback)

    var localTrialStart: Date {
        if let date = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date {
            return date
        }
        let date = Date()
        UserDefaults.standard.set(date, forKey: Self.trialStartKey)
        return date
    }

    var localTrialActive: Bool {
        Date.now < localTrialStart.addingTimeInterval(Self.trialDuration)
    }

    var trialDaysRemaining: Int {
        let end = localTrialStart.addingTimeInterval(Self.trialDuration)
        let days = Int(ceil(end.timeIntervalSince(Date.now) / 86_400))
        return max(0, days)
    }

    private static var trialDuration: TimeInterval {
        7 * 24 * 60 * 60
    }

    // MARK: Entitlement

    var isPro: Bool {
        debugUnlocked || activeSubscription || localTrialActive
    }

    // MARK: Lifecycle

    @MainActor
    func start() async {
        listenForTransactions()
        await refreshEntitlements()
    }

    private func listenForTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.monthlyProductID {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    @MainActor
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.monthlyProductID {
                active = true
            }
        }
        activeSubscription = active
    }
}
