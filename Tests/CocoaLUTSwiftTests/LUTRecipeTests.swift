import CocoaLUTSwift
import Foundation
import XCTest

final class LUTRecipeTests: XCTestCase {
    func testSerializedRecipeProducesExpectedJSON() throws {
        let action = LUTAction.changeInputBounds(lower: 0.0, upper: 1.0, name: "Bounds")
        let recipe = LUTRecipe(actions: [action])

        let data = try recipe.serializedRecipe()
        let rawJSON = try JSONSerialization.jsonObject(with: data, options: [])
        let jsonArray = try XCTUnwrap(rawJSON as? [[String: Any]])
        XCTAssertEqual(jsonArray.count, 1)

        let metadata = jsonArray[0]
        let identifier = try XCTUnwrap(metadata["id"] as? String)
        XCTAssertEqual(identifier, "ChangeInputBounds")

        let lowerBound = try XCTUnwrap(metadata["inputLowerBound"] as? Double)
        XCTAssertEqual(lowerBound, 0.0)

        let upperBound = try XCTUnwrap(metadata["inputUpperBound"] as? Double)
        XCTAssertEqual(upperBound, 1.0)
    }

    func testSerializedRecipeStringUsesUTF8Encoding() throws {
        let action = LUTAction.bypass(named: "Bypass")
        let recipe = LUTRecipe(actions: [action])

        let recipeString = try recipe.serializedRecipeString()
        XCTAssertTrue(recipeString.contains("\"id\" : \"Bypass\""))
    }
}
