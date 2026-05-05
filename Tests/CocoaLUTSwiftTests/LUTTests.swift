import Testing
@testable import CocoaLUTSwift

@Suite(.serialized)
struct LUTTests {
    @Test
    func testInitializationStoresParameters() {
        let lut = LUT(size: 4, inputLowerBound: 0.0, inputUpperBound: 1.0)
        #expect(lut.size == 4)
        #expect(lut.inputLowerBound == 0.0)
        #expect(lut.inputUpperBound == 1.0)
        #expect(lut.metadata.isEmpty)
        #expect(lut.passthroughFileOptions.isEmpty)
    }

    @Test
    func testSetAndGetColor() {
        var lut = LUT(size: 3, inputLowerBound: 0.0, inputUpperBound: 1.0)
        let target = LUTColor.color(red: 0.2, green: 0.4, blue: 0.6)
        lut.setColor(target, r: 1, g: 2, b: 0)
        #expect(lut.colorAt(r: 1, g: 2, b: 0) == target)
        #expect(lut.colorAt(r: 0, g: 0, b: 0) == .zeros())
    }

    @Test
    func testLoopVisitsAllCoordinates() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0.0, inputUpperBound: 1.0)
        var visited = Set<[Int]>()
        lut.loop { r, g, b in
            visited.insert([r, g, b])
        }
        #expect(visited.count == 8)
        #expect(visited.contains([0, 1, 0]))
    }

    @Test
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
        #expect(lut.equalsIdentity(tolerance: 1e-9))
    }

    @Test
    func testColorAtColorInterpolatesIdentity() {
        let lut = LUT.identity(size: 17, inputLowerBound: 0.0, inputUpperBound: 1.0)
        let input = LUTColor.color(red: 0.42, green: 1.5, blue: -0.4)
        let output = lut.color(at: input)
        #expect(abs(output.red - 0.42) < 1e-9)
        #expect(abs(output.green - 1.0) < 1e-9)
        #expect(abs(output.blue - 0.0) < 1e-9)
    }

    @Test
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
        #expect(abs(center.red - 0.5) < 1e-9)
        #expect(abs(center.green - 0.5) < 1e-9)
        #expect(abs(center.blue - 0.5) < 1e-9)
    }
}

private func assertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(lhs.count == rhs.count, sourceLocation: sourceLocation)
    zip(lhs, rhs).forEach { a, b in
        #expect(abs(a - b) < accuracy, sourceLocation: sourceLocation)
    }
}
