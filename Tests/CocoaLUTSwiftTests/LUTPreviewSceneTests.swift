#if canImport(AppKit) && canImport(SceneKit)
import AppKit
import SceneKit
import Testing
@testable import CocoaLUTSwift

@MainActor

@Suite
struct LUTPreviewSceneTests {
    @Test
    func testSceneBuildsExpectedDotCount() {
        var lut = LUT3D.identity(size: 3, inputLowerBound: 0, inputUpperBound: 1)
        for r in 0..<lut.size {
            for g in 0..<lut.size {
                for b in 0..<lut.size {
                    let value = Double(r + g + b) / Double((lut.size - 1) * 3)
                    let color = LUTColor.color(red: value, green: value, blue: value)
                    lut.setColor(color, r: r, g: g, b: b)
                }
            }
        }

        let scene = LUTPreviewScene.scene(for: lut)
        XCTAssertEqual(scene.dotGroup.childNodes.count, 27)
        scene.animationPercentage = 0.5
        for case let node as LUTPreviewScene.LUTColorNode in scene.dotGroup.childNodes {
            XCTAssertEqual(node.animationPercentage, 0.5, accuracy: 1e-9)
        }
    }

    @Test
    func testSceneWithUpdatedLUTReusesExistingNodes() {
        let original = LUT3D.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let scene = LUTPreviewScene.scene(for: original)

        var modified = original
        modified.setColor(LUTColor.color(red: 0.2, green: 0.4, blue: 0.6), r: 1, g: 1, b: 1)

        let updatedScene = scene.sceneWithUpdated(lut: modified)
        XCTAssertTrue(scene === updatedScene)
        let targetNode = updatedScene.dotGroup.childNodes.compactMap { $0 as? LUTPreviewScene.LUTColorNode }.first { node in
            node.r == 1 && node.g == 1 && node.b == 1
        }
        XCTAssertNotNil(targetNode)
        if let targetNode {
            XCTAssertEqual(targetNode.transformedColor.red, 0.2, accuracy: 1e-6)
        }
    }
}
#endif
