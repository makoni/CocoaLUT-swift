import Testing
@testable import CocoaLUTSwift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct LUTColorMissingAPITests {

    @Test func testLuminance() {
        let color = LUTColor(red: 1, green: 0, blue: 0)
        // Rec 709: 0.2126 R + 0.7152 G + 0.0722 B
        let expected = 0.2126 * 1.0 + 0.7152 * 0.0 + 0.0722 * 0.0
        #expect(abs(color.luminanceRec709() - expected) < 0.0001)
    }

    @Test func testInvertedColor() {
        let color = LUTColor(red: 0.2, green: 0.3, blue: 0.4)
        let inverted = color.inverted(minimumValue: 0, maximumValue: 1)
        #expect(abs(inverted.red - 0.8) < 0.0001)
        #expect(abs(inverted.green - 0.7) < 0.0001)
        #expect(abs(inverted.blue - 0.6) < 0.0001)
    }

    @Test func testSystemColor() {
        let color = LUTColor(red: 0.5, green: 0.5, blue: 0.5)
        #if canImport(AppKit)
        let nsColor = color.systemColor
        #expect(nsColor.redComponent == 0.5)
        #elseif canImport(UIKit)
        let uiColor = color.systemColor
        var r: CGFloat = 0
        uiColor.getRed(&r, green: nil, blue: nil, alpha: nil)
        #expect(r == 0.5)
        #endif
    }

    @Test func testStringFormatting() {
        let color = LUTColor(red: 0.123456, green: 0.654321, blue: 0.987654)
        let str = color.stringFormatted(withFloatingPointLength: 3)
        // Expected format: "0.123 0.654 0.988" (or similar, depending on separator)
        // ObjC usually did space separated.
        #expect(str == "0.123 0.654 0.988")
    }
}
