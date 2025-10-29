import XCTest
@testable import CocoaLUT_swift

final class LUTTests: XCTestCase {
    func testInitializationStoresParameters() {
        let lut = LUT(size: 4, inputLowerBound: 0.0, inputUpperBound: 1.0)
        XCTAssertEqual(lut.size, 4)
        XCTAssertEqual(lut.inputLowerBound, 0.0)
        XCTAssertEqual(lut.inputUpperBound, 1.0)
        XCTAssertTrue(lut.metadata.isEmpty)
        XCTAssertTrue(lut.passthroughFileOptions.isEmpty)
    }

    func testSetAndGetColor() {
        var lut = LUT(size: 3, inputLowerBound: 0.0, inputUpperBound: 1.0)
        let target = LUTColor.color(red: 0.2, green: 0.4, blue: 0.6)
        lut.setColor(target, r: 1, g: 2, b: 0)
        XCTAssertEqual(lut.colorAt(r: 1, g: 2, b: 0), target)
        XCTAssertEqual(lut.colorAt(r: 0, g: 0, b: 0), .zeros())
    }

    func testLoopVisitsAllCoordinates() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0.0, inputUpperBound: 1.0)
        var visited = Set<[Int]>()
        lut.loop { r, g, b in
            visited.insert([r, g, b])
        }
        XCTAssertEqual(visited.count, 8)
        XCTAssertTrue(visited.contains([0, 1, 0]))
    }

    func testIdentityMatchesBounds() {
        let size = 5
        let lut = LUT.identity(size: size, inputLowerBound: -1.0, inputUpperBound: 2.0)
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let expected = lut.identityColorAt(r: Double(r), g: Double(g), b: Double(b))
                    let actual = lut.colorAt(r: r, g: g, b: b)
                    assertEqual(actual.rgbArray(), expected.rgbArray(), accuracy: 1e-9)
                }
            }
        }
        XCTAssertTrue(lut.equalsIdentity(tolerance: 1e-9))
    }

    func testColorAtColorInterpolatesIdentity() {
        let lut = LUT.identity(size: 17, inputLowerBound: 0.0, inputUpperBound: 1.0)
        let input = LUTColor.color(red: 0.42, green: 1.5, blue: -0.4)
        let output = lut.color(at: input)
        XCTAssertEqual(output.red, 0.42, accuracy: 1e-9)
        XCTAssertEqual(output.green, 1.0, accuracy: 1e-9)
        XCTAssertEqual(output.blue, 0.0, accuracy: 1e-9)
    }

    func testResizingInterpolatesValues() {
        var lut = LUT(size: 2, inputLowerBound: 0.0, inputUpperBound: 1.0)
        lut.setColor(.zeros(), r: 0, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 1.0, green: 0.0, blue: 0.0), r: 1, g: 0, b: 0)
        lut.setColor(LUTColor.color(red: 0.0, green: 1.0, blue: 0.0), r: 0, g: 1, b: 0)
        lut.setColor(LUTColor.color(red: 1.0, green: 1.0, blue: 0.0), r: 1, g: 1, b: 0)
        lut.setColor(LUTColor.color(red: 0.0, green: 0.0, blue: 1.0), r: 0, g: 0, b: 1)
        lut.setColor(LUTColor.color(red: 1.0, green: 0.0, blue: 1.0), r: 1, g: 0, b: 1)
        lut.setColor(LUTColor.color(red: 0.0, green: 1.0, blue: 1.0), r: 0, g: 1, b: 1)
        lut.setColor(LUTColor.ones(), r: 1, g: 1, b: 1)

        let resized = lut.resized(to: 3)
        let center = resized.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(center.red, 0.5, accuracy: 1e-9)
        XCTAssertEqual(center.green, 0.5, accuracy: 1e-9)
        XCTAssertEqual(center.blue, 0.5, accuracy: 1e-9)
    }
}

private func assertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
    zip(lhs, rhs).forEach { a, b in
        XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line)
    }
}
