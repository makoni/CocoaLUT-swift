import Testing
import CoreImage
@testable import CocoaLUTSwift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite(.serialized) struct LUTCoreImageMissingAPITests {
    
    @Test func testCoreImageFilter() throws {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try lut.coreImageFilter()
        
        #expect(filter.name == "CIColorCube")
    }
    
    @Test func testProcessCIImage() {
        let lut = LUT.identity(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        let image = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        
        let output = lut.process(ciImage: image)
        
        #expect(output != nil)
    }
}
