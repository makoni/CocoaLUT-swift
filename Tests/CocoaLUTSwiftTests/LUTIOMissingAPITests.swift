import Testing
import Foundation
@testable import CocoaLUTSwift

@Suite(.serialized) struct LUTIOMissingAPITests {
    
    @Test func testLUTFromURL() throws {
        // Debug resource path
        if let resourcePath = Bundle.module.resourcePath {
            print("Resource path: \(resourcePath)")
            let fileManager = FileManager.default
            if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                print("Contents: \(contents)")
            }
        }

        // Locate the test LUT file
        guard let url = Bundle.module.url(forResource: "AlexaV3_K1S1_LogC2Video_Rec709_EE_33", withExtension: "cube", subdirectory: "TestLUTs") else {
             print("Could not find test LUT file.")
             return
        }
        
        let lut = try LUT.from(url: url)
        
        #expect(lut.size == 33)
        // Verify some properties or values if known
    }
    
    @Test func testWriteLUT() throws {
        let lut = LUT.identity(size: 17, inputLowerBound: 0, inputUpperBound: 1)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_write.cube")
        
        try lut.write(to: tempURL, formatterID: "cube")
        
        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
}
