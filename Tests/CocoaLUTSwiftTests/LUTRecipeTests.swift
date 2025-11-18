import CocoaLUTSwift
import Foundation
import Testing

@Suite
struct LUTRecipeTests {
    @Test
    func testSerializedRecipeProducesExpectedJSON() throws {
        let action = LUTAction.changeInputBounds(lower: 0.0, upper: 1.0, name: "Bounds")
        let recipe = LUTRecipe(actions: [action])

        let data = try recipe.serializedRecipe()
        let rawJSON = try JSONSerialization.jsonObject(with: data, options: [])
        let jsonArray = try #require(rawJSON as? [[String: Any]])
        #expect(jsonArray.count == 1)

        let metadata = jsonArray[0]
        let identifier = try #require(metadata["id"] as? String)
        #expect(identifier == "ChangeInputBounds")

        let lowerBound = try #require(metadata["inputLowerBound"] as? Double)
        #expect(lowerBound == 0.0)

        let upperBound = try #require(metadata["inputUpperBound"] as? Double)
        #expect(upperBound == 1.0)
    }

    @Test
    func testSerializedRecipeStringUsesUTF8Encoding() throws {
        let action = LUTAction.bypass(named: "Bypass")
        let recipe = LUTRecipe(actions: [action])

        let recipeString = try recipe.serializedRecipeString()
        #expect(recipeString.contains("\"id\" : \"Bypass\""))
    }
}
