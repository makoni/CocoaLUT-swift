import Testing
@testable import CocoaLUTSwift

struct LUTOperationsMissingAPITests {

    @Test func testColorInterpolated() {
        // Create a simple 2x2x2 LUT
        var lut = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        // Set (0,0,0) to black, (1,1,1) to white
        lut.setColor(.zeros(), r: 0, g: 0, b: 0)
        lut.setColor(.ones(), r: 1, g: 1, b: 1)
        
        // Interpolate at center (0.5, 0.5, 0.5)
        // Since it's trilinear interpolation, and we only set corners, 
        // let's set all corners to make it predictable or just check bounds.
        // Actually, let's use identity LUT.
        let identity = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let color = identity.colorInterpolated(r: 0.5, g: 0.5, b: 0.5)
        
        // Identity at 0.5 (index) corresponds to 0.5 value?
        // Size 2: index 0 -> 0.0, index 1 -> 1.0.
        // Index 0.5 -> 0.5.
        #expect(abs(color.red - 0.5) < 0.0001)
    }

    @Test func testCombineWithLUT() {
        // LUT A: Identity
        let lutA = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        // LUT B: Inverts colors (conceptually)
        // Let's make a small LUT that inverts.
        var lutB = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lutB.loop { r, g, b in
            // Invert: 0 -> 1, 1 -> 0
            let valR = 1.0 - Double(r)
            let valG = 1.0 - Double(g)
            let valB = 1.0 - Double(b)
            lutB.setColor(LUTColor(red: valR, green: valG, blue: valB), r: r, g: g, b: b)
        }
        
        // Combine: A then B. Since A is identity, result should be B.
        let combined = lutA.combined(with: lutB)
        
        // Check corner (0,0,0) -> A -> (0,0,0) -> B -> (1,1,1)
        let c0 = combined.colorAt(r: 0, g: 0, b: 0)
        #expect(abs(c0.red - 1.0) < 0.0001)
        
        // Check corner (1,1,1) -> A -> (1,1,1) -> B -> (0,0,0)
        let c1 = combined.colorAt(r: 1, g: 1, b: 1)
        #expect(abs(c1.red - 0.0) < 0.0001)
    }
}
