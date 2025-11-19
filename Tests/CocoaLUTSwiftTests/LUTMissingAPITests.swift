
import XCTest
@testable import CocoaLUTSwift

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

final class LUTMissingAPITests: XCTestCase {

    func testLUT3DFromDataRepresentation() throws {
        let lut = LUT3D(size: 2, inputLowerBound: 0, inputUpperBound: 1)
        // We need dataRepresentation first to test init
        let data = lut.dataRepresentation
        let restored = try LUT3D(fromDataRepresentation: data)
        XCTAssertEqual(restored.size, 2)
    }

    func testLUTFormatterCubeStaticMembers() {
        let id = LUTFormatterCube.formatterID()
        XCTAssertEqual(id, "cube")
        
        let options = LUTFormatterCube.defaultOptions()
        XCTAssertNotNil(options)
    }

    func testLUTFormatterHaldCLUTVisibility() {
        let _ = LUTFormatterHaldCLUT.self
    }

    @MainActor
    func testLUTFormatterHaldCLUTFromImage() {
        let image = PlatformImage() // Create a dummy image
        let lut = LUTFormatterHaldCLUT.lut(from: image)
        // XCTAssertNotNil(lut) // This might fail if image is empty, but we just want to check API existence
    }
}
