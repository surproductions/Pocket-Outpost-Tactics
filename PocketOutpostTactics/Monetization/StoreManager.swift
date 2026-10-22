import StoreKit
import SwiftUI

/// StoreKit 2: one optional, cosmetic-only non-consumable ("Supporter Pack"). No ads, no
/// consumables, nothing that affects combat. If the product isn't configured in App Store Connect
/// the shop simply hides the purchase card.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static var supporterPackID: String {
        (Bundle.main.bundleIdentifier ?? "com.surproductions.pocketoutposttactics") + ".supporterpack"
    }

    @Published private(set) var supporterProduct: Product?
    @Published private(set) var ownsSupporterPack = false
    @Published private(set) var isLoading = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            supporterProduct = try await Product.products(for: [Self.supporterPackID]).first
        } catch {
            supporterProduct = nil
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owns = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.supporterPackID, t.revocationDate == nil {
                owns = true
            }
        }
        ownsSupporterPack = owns
    }

    func purchaseSupporterPack() async {
        guard let product = supporterProduct else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
                message = "Thank you for supporting Pocket Outpost Tactics!"
            case .pending:
                message = "Purchase pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase couldn't be completed. Please try again."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = ownsSupporterPack ? "Purchases restored." : "No previous purchases found."
        } catch {
            message = "Couldn't reach the App Store. Please try again."
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.supporterPackID {
            ownsSupporterPack = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
