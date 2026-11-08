import StoreKit
import StoreKitTest
import XCTest
@testable import PettyOptician

final class TipJarTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "PettyOptician")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    func testEveryTipIsAConsumableInTheStoreKitConfig() async throws {
        let products = try await Product.products(for: Tip.allCases.map(\.productID))
        XCTAssertEqual(Set(products.map(\.id)), Set(Tip.allCases.map(\.productID)))
        XCTAssertTrue(products.allSatisfy { $0.type == .consumable })
        for tip in Tip.allCases {
            XCTAssertEqual(products.first { $0.id == tip.productID }?.displayPrice, tip.fallbackPrice, tip.rawValue)
        }
    }

    func testBuyingATipSucceedsAndCanRepeat() async throws {
        let products = try await Product.products(for: [Tip.coffee.productID])
        let coffee = try XCTUnwrap(products.first)
        var purchases = 0
        for _ in 0..<2 {
            guard case .success(.verified(let transaction)) = try await coffee.purchase() else {
                return XCTFail("Tip purchase did not verify")
            }
            XCTAssertEqual(transaction.productID, Tip.coffee.productID)
            await transaction.finish()
            purchases += 1
        }
        XCTAssertEqual(purchases, 2)
    }
}
