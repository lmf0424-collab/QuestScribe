import StoreKit
import SwiftUI

// MARK: - Paywall

/// StoreKit-driven paywall with a 7-day free trial then $12.99/month.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(groupID: PaywallManager.groupID) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("QuestScribe Pro")
                        .font(.largeTitle.bold())

                    Text("Scan unlimited handwritten prep notes mid-session. Try it free for 7 days, then $12.99/month. Cancel anytime.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
            }
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStoreButtonLabel(.multiline)
            .subscriptionStoreControlStyle(.automatic)
            .subscriptionStorePickerItemStyle(.prominent)
            .navigationTitle("QuestScribe Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not Now") { dismiss() }
                }
            }
        }
    }
}
