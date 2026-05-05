import Testing
#if canImport(CoreImage)
import CoreImage
import CoreGraphics
#endif
@testable import CocoaLUTSwift

@Suite(.serialized)
struct ObjCCompatibilityTests {
#if canImport(CoreImage)
    @Test
    func testCoreImageFilterWithCurrentColorSpaceMatchesObjCBehaviour() throws {
        // ObjC `-coreImageFilterWithCurrentColorSpace` always builds a
        // CIColorCubeWithColorSpace filter using deviceRGB. A previous version of
        // this Swift shim passed `nil` here, which silently downgraded the filter
        // to a plain CIColorCube and produced visibly weaker LUT effects in
        // hosting apps (Camo Studio's BACK_MACHINE filter looked desaturated).
        let lut = LUT.identity(size: 4, inputLowerBound: 0, inputUpperBound: 1)
        let filter = try lut.coreImageFilterWithCurrentColorSpace()
        #expect(filter.name == "CIColorCubeWithColorSpace")
        #expect(filter.value(forKey: "inputColorSpace") != nil)
    }
#endif


    @Test
    func testLUTDataRepresentationRoundTrip3D() throws {
        let identity = LUT.identity(size: 17,
                                    inputLowerBound: 0,
                                    inputUpperBound: 1)

        let data = try #require(identity.dataRepresentation, "Expected cube payload for identity LUT")
        let decoded = try #require(LUT(fromDataRepresentation: data))

        #expect(decoded.equals(identity, tolerance: 1e-9))
    }

    @Test
    func testLUTDataRepresentationRoundTrip1D() throws {
        let curve = LUT1D.uniformCurve(size: 65,
                                       inputLowerBound: 0,
                                       inputUpperBound: 1)

        let cube = curve.toLUT3D(size: curve.size).asLUT()
        let data = try #require(cube.dataRepresentation, "Expected cube payload for converted 1D LUT")
        let decoded = try #require(LUT(fromDataRepresentation: data))

        let reconstructedCurve = LUT3D(lattice: decoded).toLUT1D()
        assertEqual(curve, reconstructedCurve, accuracy: 1e-9)
    }
}

private func assertEqual(_ lhs: LUT1D,
                         _ rhs: LUT1D,
                         accuracy: Double,
                         sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(lhs.size == rhs.size, sourceLocation: sourceLocation)
    #expect(abs(lhs.inputLowerBound - rhs.inputLowerBound) < accuracy, sourceLocation: sourceLocation)
    #expect(abs(lhs.inputUpperBound - rhs.inputUpperBound) < accuracy, sourceLocation: sourceLocation)

    for index in 0..<lhs.size {
        #expect(abs(lhs.valueAtR(index) - rhs.valueAtR(index)) < accuracy, sourceLocation: sourceLocation)
        #expect(abs(lhs.valueAtG(index) - rhs.valueAtG(index)) < accuracy, sourceLocation: sourceLocation)
        #expect(abs(lhs.valueAtB(index) - rhs.valueAtB(index)) < accuracy, sourceLocation: sourceLocation)
    }
}
