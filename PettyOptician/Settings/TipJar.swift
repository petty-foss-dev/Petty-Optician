import StoreKit
import SwiftUI

/// One-time consumable tips; nothing in the app is gated on them.
enum Tip: String, CaseIterable, Identifiable {
    case coffee, lunch, celebration, generous

    var id: String { productID }

    var productID: String { "com.isaaclamb.PettyOptician.tip.\(rawValue)" }

    var title: String {
        switch self {
        case .coffee: "A coffee"
        case .lunch: "A study-break lunch"
        case .celebration: "A passed-the-exam celebration"
        case .generous: "Extremely generous"
        }
    }

    var symbol: String {
        switch self {
        case .coffee: "cup.and.saucer"
        case .lunch: "takeoutbag.and.cup.and.straw"
        case .celebration: "party.popper"
        case .generous: "heart"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .coffee: "$0.99"
        case .lunch: "$2.99"
        case .celebration: "$4.99"
        case .generous: "$9.99"
        }
    }
}

extension Tip {
    /// Tips approved later (Ask to Buy, interrupted purchases) arrive here and must be finished.
    static func finishLateTransactions() -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
            }
        }
    }
}

struct TipJarView: View {
    @Environment(\.palette) private var palette
    @State private var products: [String: Product] = [:]
    @State private var purchasing: Tip?
    @State private var errorMessage: String?
    @State private var thanked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "heart.text.square")
                            .font(.largeTitle)
                            .foregroundStyle(palette.accent)
                        Text("Say thanks")
                            .font(.title2.weight(.bold))
                        Text("If this free resource helped you pass, or is helping you review for an upcoming exam, and you'd like to say thank you, you can leave a tip here.")
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("It's completely optional. Every question, guide and trainer stays free either way.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(Tip.allCases) { tipRow($0) }
                }

                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }

                Text("One-time payment, never a subscription. Handled by Apple.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProducts() }
        .alert("Thank you!", isPresented: $thanked) {
            Button("You're welcome", role: .cancel) {}
        } message: {
            Text("That really helps. Good luck on your exam.")
        }
    }

    private func tipRow(_ tip: Tip) -> some View {
        Button { Task { await purchase(tip) } } label: {
            Panel(padding: 14) {
                HStack(spacing: 14) {
                    Group {
                        if purchasing == tip {
                            ProgressView()
                        } else {
                            Image(systemName: tip.symbol).font(.title3).foregroundStyle(palette.accent)
                        }
                    }
                    .frame(width: 32)
                    Text(tip.title).font(.headline).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                    Spacer()
                    Text(products[tip.productID]?.displayPrice ?? tip.fallbackPrice)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(purchasing != nil)
        .accessibilityIdentifier("tip.\(tip.rawValue)")
    }

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Tip.allCases.map(\.productID))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    private func purchase(_ tip: Tip) async {
        guard let product = products[tip.productID] else {
            errorMessage = "Tips aren't available right now. Please try again later."
            return
        }
        purchasing = tip
        errorMessage = nil
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                thanked = true
            case .success(.unverified(let transaction, _)):
                await transaction.finish()
                errorMessage = "Apple couldn't verify that purchase, so it wasn't completed."
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase didn't go through: \(error.localizedDescription)"
        }
    }
}
