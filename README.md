# CocoaLUT

A Swift 6-first library for reading, writing, and manipulating 1D and 3D look up tables (LUTs). CocoaLUT began as an Objective-C project; the Swift package in `Sources/CocoaLUTSwift` now provides full feature parity and exposes the formatter registry, Core Image helpers, AVFoundation video preview, and SceneKit/AppKit preview utilities.

![Lattice preview](lattice.png)

## Project status

- **Swift package:** `CocoaLUTSwift` library builds with Swift 6 and strict concurrency checking. 100% ObjC parity (254 tests / 46 suites passing under `-strict-concurrency=complete`).
- **Platforms:** macOS (AppKit + SceneKit + AVFoundation), macCatalyst, iOS, tvOS, watchOS, and visionOS targets are available via SwiftPM resources.
- **Optional GPUImage:** GPUImage helpers compile when the dependency is supplied (`canImport(GPUImage)` guards remain in place).

## Installation

### Swift Package Manager (recommended)

Add CocoaLUT to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/makoni/CocoaLUT-swift.git", branch: "swift")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "CocoaLUTSwift", package: "CocoaLUT-swift")
            ])
    ]
)
```

Then fetch dependencies and run the test suite:

```bash
swift build
swift test -Xswiftc -strict-concurrency=complete
```

## Quick start

```swift
import CocoaLUTSwift
import CoreImage

let cubeURL = Bundle.main.url(forResource: "Linear_to_BMDFilm", withExtension: "cube")!
let lut = try CocoaLUT.readLUT(from: cubeURL)

// Apply to a CIImage using the Core Image pipeline
let context = CIContext()
if let output = lut.process(ciImage: inputImage) {
    let rendered = context.createCGImage(output, from: output.extent)
    // use rendered image
}

// Write the LUT back out as a Resolve-compatible cube file
let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("custom.cube")
try CocoaLUT.write(lut: lut, to: outputURL, formatterID: LUTFormatterIdentifier.cube)
```

## Format support
| Type | Formats |
| ---- | --------|
| 3D LUT | Cube (`.cube`), Autodesk (`.3dl`), Quantel (`.txt`), FSI DAT (`.dat`), Clipster (`.xml`, `.txt`), Nucoda CMS (`.cms`), Resolve DAT (`.dat`), DaVinci (`.davlut`), Unwrapped texture images (`.tiff`, `.dpx`, `.png`), CMS test pattern images (`.tiff`, `.dpx`, `.png`), Hald CLUT images (`.tiff`, `.dpx`, `.png`), ICC profiles (`.icc`, `.icm`, `.pf`, `.prof` on macOS)
| 1D LUT | Cube (`.cube`), Nucoda CMS (`.cms`), DaVinci ILUT/OLUT (`.ilut`, `.olut`), Discreet (`.lut`), Arri Look tone map (`.xml`)

All formatters are registered through `LUTFormatterRegistry`, so facade calls such as `CocoaLUT.readLUT` automatically pick the correct reader based on file extension or identifier.

## More capabilities

- Apply LUTs to `CIImage`, `NSImage`, and `UIImage` with built-in color space handling.
- Generate `CIColorCube` filters and platform preview helpers — SceneKit point clouds with cube outline and R/G/B axes (`LUTPreviewScene`), AVPlayer-backed video preview with masked LUT comparison (`LUTPreviewView`), and a 1D curve graph with mouse-tracking overlay and `LUT1DGraphViewController` (`LUT1DGraphView`).
- Resize, combine, clamp, remap, offset, and otherwise transform LUTs in-memory.
- Reverse monotonic 1D LUTs and apply LUT3D transformations: `applyingFalseColor()`, `extractingContrastOnly()`, `extractingColorShift(strictness:)`, `convertingToMono(method:)` with five Rec.709-aware methods, `applyingColorMatrix(columnMajor:)`, and `swizzling1DChannels(method:strictness:)`.
- Convert LUT color spaces and color temperatures using the ported color science utilities (21 predefined color spaces, 17 transfer functions, Bradford adaptation, Robertson-approximation white points).

## Contributing

- Use `swift test -Xswiftc -strict-concurrency=complete` before opening PRs.
- Follow the modern Swift guidelines documented in `.github/instructions`.

## Authors

- [Wil Gieseler](https://github.com/wilg)
- [Greg Cotten](https://github.com/gregcotten)
- [Tashi Trieu](https://github.com/tashdor) — Color science
- [Various contributors](https://github.com/makoni/CocoaLUT-swift/graphs/contributors)

## License

CocoaLUT is available under the MIT license. See [LICENSE](LICENSE) for details.

