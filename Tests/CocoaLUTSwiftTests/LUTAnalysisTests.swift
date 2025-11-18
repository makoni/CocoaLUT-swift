import XCTest
@testable import CocoaLUTSwift

final class LUTAnalysisTests: XCTestCase {
    
    func testCombined() {
        // Create a simple identity LUT
        let lut1 = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        // Create a LUT that inverts colors
        var lut2 = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        lut2.setColor(LUTColor(red: 1, green: 1, blue: 1), r: 0, g: 0, b: 0) // Black -> White
        lut2.setColor(LUTColor(red: 0, green: 0, blue: 0), r: 1, g: 1, b: 1) // White -> Black
        // Set other corners to something predictable
        lut2.setColor(LUTColor(red: 0, green: 1, blue: 1), r: 1, g: 0, b: 0) // Red -> Cyan
        
        // Combine lut1 (identity) with lut2 (invert) -> should be lut2
        let combined = lut1.combined(with: lut2)
        
        XCTAssertEqual(combined.size, 2)
        
        // Check Black -> White
        let c1 = combined.colorAt(r: 0, g: 0, b: 0)
        XCTAssertEqual(c1.red, 1, accuracy: 1e-5)
        XCTAssertEqual(c1.green, 1, accuracy: 1e-5)
        XCTAssertEqual(c1.blue, 1, accuracy: 1e-5)
        
        // Check White -> Black
        let c2 = combined.colorAt(r: 1, g: 1, b: 1)
        XCTAssertEqual(c2.red, 0, accuracy: 1e-5)
        XCTAssertEqual(c2.green, 0, accuracy: 1e-5)
        XCTAssertEqual(c2.blue, 0, accuracy: 1e-5)
    }
    
    func testEqualsLUTEssence() {
        let lut1 = LUT(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let lut2 = LUT(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let lut3 = LUT(size: 33, inputLowerBound: 0, inputUpperBound: 1)
        
        XCTAssertTrue(lut1.equalsLUTEssence(comparingTo: lut2))
        XCTAssertFalse(lut1.equalsLUTEssence(comparingTo: lut3))
        
        var lut4 = LUT(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        lut4 = lut4.changingInputBounds(lower: 0.1, upper: 1.0)
        XCTAssertFalse(lut1.equalsLUTEssence(comparingTo: lut4))
    }
    
    func testAnalysisMetrics() {
        var lut1 = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        var lut2 = LUT(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        
        // Set all to black
        for r in 0..<2 {
            for g in 0..<2 {
                for b in 0..<2 {
                    lut1.setColor(LUTColor(red: 0, green: 0, blue: 0), r: r, g: g, b: b)
                    lut2.setColor(LUTColor(red: 0, green: 0, blue: 0), r: r, g: g, b: b)
                }
            }
        }
        
        // lut1: Black everywhere
        // lut2: Black everywhere except (0,0,0) is (0.1, 0.1, 0.1)
        lut2.setColor(LUTColor(red: 0.1, green: 0.1, blue: 0.1), r: 0, g: 0, b: 0)
        
        // Max Error: 0.1
        let maxError = lut1.maximumAbsoluteError(comparingTo: lut2)
        XCTAssertEqual(maxError.red, 0.1, accuracy: 1e-5)
        XCTAssertEqual(maxError.green, 0.1, accuracy: 1e-5)
        XCTAssertEqual(maxError.blue, 0.1, accuracy: 1e-5)
        
        // Avg Error: 0.1 / 8 = 0.0125
        let avgError = lut1.averageAbsoluteError(comparingTo: lut2)
        XCTAssertEqual(avgError.red, 0.0125, accuracy: 1e-5)
        XCTAssertEqual(avgError.green, 0.0125, accuracy: 1e-5)
        XCTAssertEqual(avgError.blue, 0.0125, accuracy: 1e-5)
        
        // SMAPE
        // At (0,0,0): |0 - 0.1| / (0 + 0.1) = 0.1 / 0.1 = 1.0
        // At others: 0
        // Avg SMAPE: 1.0 / 8 = 0.125
        let smape = lut1.symmetricalMeanAbsolutePercentageError(comparingTo: lut2)
        XCTAssertEqual(smape.red, 0.125, accuracy: 1e-5)
        XCTAssertEqual(smape.green, 0.125, accuracy: 1e-5)
        XCTAssertEqual(smape.blue, 0.125, accuracy: 1e-5)
    }
}
