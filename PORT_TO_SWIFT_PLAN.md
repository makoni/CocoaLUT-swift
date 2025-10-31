# Port CocoaLUT to Swift 6 — Plan & AI agent instructions

This document is an actionable plan for porting the CocoaLUT Objective‑C codebase to Swift 6 as a Swift Package, using Test‑Driven Development (TDD). It is written for the human maintainer and for the AI agent that will do the porting work.

## Status (updated 2025-10-31)

- **Completion estimate:** ~88% of the Objective‑C surface has Swift equivalents with green tests (core math, processors, formatters, color spaces, GPUImage shim, and image-based helpers).
- **What remains for 100% parity:** retire the remaining Objective‑C transition headers and document the Swift-first API surface.
- **Next focus:** smooth out concurrency annotations and refresh the README/API docs for the Swift facade.

Summary
- Goal: Produce a Swift 6 implementation of the library (module name `CocoaLUTSwift`), preserve public API behavior, and keep a SwiftPM-first workflow. Maintain Objective‑C compatibility where needed for existing apps until migration is complete.
- Strategy: Port incrementally, feature-by-feature, using TDD. Port core data model and pure logic first (LUT data structures, color math), then formatting (read/write), then platform rendering/wrapping (CoreImage/GPUImage), then utility/UI pieces.

How to use this plan
- The AI agent should follow the checklist below. For each file to port:
  1. Create a failing unit test that expresses the expected behavior (read existing tests in `Tests/` for behavior examples).
  2. Implement a minimal Swift type that satisfies the test.
  3. Expand tests to cover edge cases and interop.
  4. Iterate until tests pass.

Branching and workflow
- Continue working on the current feature branch (this repository already contains the `swift` branch). Work in small commits and open PRs back to `swift` (or `master` as desired).
- Keep the SPM `Package.swift` as the canonical build for Swift; keep `Sources/CocoaLUT-swift/` as the Swift entry point. For ObjC-only features (GPUImage), keep small bridging shims until fully ported.

Test Driven Development rules (strict)
- Every ported public API must have at least one unit test before implementation.
- Prefer value semantics in Swift for small value types (e.g., `LUTColor` -> struct that is `Sendable`).
- Use XCTest with `swift test`. Add tests under `Tests/CocoaLUTSwiftTests/` matching package layout.
- When porting code that uses global state or singletons, write tests that run in isolation (reset global state between tests).

## Progress tracker (updated 2025-10-31)

- [x] Establish Swift test target `CocoaLUTSwiftTests` scaffold.
- [x] Port `LUTColor` with arithmetic/clamping tests.
- [x] Port `LUT` core lattice representation and identity tests.
- [x] Port `LUT1D`/`LUT3D` minimal functionality with conversion tests.
- [x] Port `LUTHelper` functions required by the core types.
- [x] Port `LUTFormatterCube` with round-trip IO tests.
- [x] Port remaining formatters (3DL, Hald, UnwrappedTexture, etc.).
  - [x] 3DL formatter with read/write round-trip tests.
  - [x] Hald CLUT formatter with image round-trip tests.
  - [x] Unwrapped texture formatter with image round-trip tests.
  - [x] ILUT formatter with read/write validation.
  - [x] Quantel formatter with integer scaling tests.
  - [x] Nucoda CMS formatter (1D/3D combined) with combination tests.
  - [x] FSI DAT formatter with binary round-trip tests.
  - [x] Resolve DAT formatter (including DaVinci DAVLUT variant) with read/write tests.
  - [x] Arri Look formatter with tone map and SOP interplay tests.
  - [x] Clipster formatter with XML round-trip tests.
  - [x] MatchLight formatter with combined 1D/3D tests.
  - [x] OLUT formatter with CSV read/write tests.
  - [x] CMS Test Pattern formatter with layout and PNG round-trip tests.
- [x] Port processing stack (`LUTProcessor`, `LUTReverser`, `LUTAction`).
  - [x] LUTProcessor base class with cancellation/progress support.
  - [x] LUTReverser scaffold.
  - [x] LUTAction chainable operations.
    - [x] Scale/remap/offset/combine/color-matrix factories with caching.
    - [x] Swizzle actions for 1D/3D LUTs.
    - [x] Color-temperature conversion action (requires color space utilities).
    - [x] Tests covering new swizzle and color-temperature behaviors.
    - [x] Verify change-input-bounds action parity with tests.
    - [x] Verify clamp action bounds preservation with tests.
    - [x] Verify resize action resamples lattice with tests.
    - [x] Verify combine/combine-behind actions with tests.
    - [x] Verify action caching propagates metadata with tests.
- [x] Port color space and transfer utilities (`LUTColorSpace`, `LUTColorTransferFunction`, `LUTColorSpaceWhitePoint`).
  - [x] `LUTColorSpaceWhitePoint` creation helpers and temperature conversion.
  - [x] `LUTColorSpace` primaries/transfer conversions.
  - [x] `LUTColorTransferFunction` gamma/log helpers.
- [x] Port platform glue (Core Image wrappers, GPUImage shim, macOS preview utilities).
  - [x] Implement `LUTImageRenderPath` enum and public API for image rendering entry points.
  - [x] Add Core Image filter generation (`coreImageFilter(colorSpace:)`) with tests.
  - [x] Add `process(ciImage:)` pipeline and verify output via `CIContext` sampling.
  - [x] Provide platform-specific image helpers (`processUIImage`, `processNSImage`) with coverage where possible.
  - [x] Bridge GPUImage wrapper or supply placeholder shim with tests (pending GPUImage availability).

### Remaining items for full parity (identified 2025-10-30)

- [x] Port `LUTFormatterICCProfile` to Swift (macOS only) and add read/write regression tests using sample ICC data.
- [x] Port the macOS preview stack to SwiftUI/AppKit (`LUTPreviewScene`, `LUTPreviewImageGenerator`, `LUTPreviewView`, `LUT1DGraphView`) with lightweight rendering tests where possible.
- [x] Recreate a Swift formatter registry/entry points mirroring `LUTFormatter` discovery (`formatters(for:)`, convenience read/write on `LUT`).
  - [x] Establish registry infrastructure (`LUTFormatterDescriptor`, payload enum, `CocoaLUT` facade constants/tests).
  - [x] Register initial formatter (Cube) and prove read/write plumbing via tests.
  - [x] Add Hald CLUT formatter coverage to the registry with TIFF round-trip tests.
  - [x] Add Unwrapped texture formatter coverage (PNG/TIFF) to the registry with read/write facade tests.
  - [x] Register ILUT/OLUT descriptors with passthrough normalization and round-trip facade coverage.
  - [x] Incrementally add remaining formatters + legacy aliases with regression coverage.
    - [x] Register FSIDAT, Clipster, Discreet, CMS Test Pattern, Nucoda CMS, and Arri Look descriptors with normalization coverage tests.
    - [x] Align Cube formatter identifier with Objective-C canonical ID while retaining legacy alias coverage.
    - [x] Mirror default and passthrough options across canonical and legacy identifiers for all registered formatters, with facade regression tests.
    - [x] Add MatchLight aliases and the remaining legacy sidecars.
      - [x] Support MatchLight alias lookup (camel-case and lowercase identifiers).
      - [x] Wire remaining legacy sidecar descriptors.
- [x] Replace `CocoaLUT.h` macros with Swift symbols (constants for suggested sizes, `SystemColor` alias) and populate `CocoaLUT_swift.swift` as the public facade.
- [x] Remove or port the legacy Objective‑C image-based formatter scaffolding (`LUTFormatterImageBased`) once the Swift helpers cover all use cases.
- [ ] Update README/API docs to describe the Swift-first surface and deprecation path for the Objective‑C headers.

> Maintain TDD discipline: every item above remains unchecked until tests are in place and passing.

Mapping guidelines (Objective‑C -> Swift)
- Prefer Swift-native types: `NSArray/NSDictionary` -> `[T]`/`[K:V]`, `NSNumber` -> `Double/Int`.
- For small immutable data, use `struct` (e.g., `LUTColor` -> struct LUTColor: Sendable).
- For large mutable structures representing lattice (LUT, LUT1D, LUT3D), prefer `class` where mutation and identity are expected; consider copy-on-write if performance matters.
- Expose the same high-level APIs but with Swift naming conventions. Keep legacy Objective‑C selectors available via @objc shims in a transitional module if needed.

Porting priority
1. Core data model & math (high confidence, low external deps) — `LUT`, `LUTColor`, `LUT1D`, `LUT3D`, `LUTHelper`.
2. Transforms and processors — `LUTProcessor`, `LUTReverser`, `LUTRecipe`, `LUTAction`.
3. Formatters (IO) — all `LUTFormatter*` classes; port reading and writing for the most-used formats first (`Cube`, `3DL`, `Hald`, `UnwrappedTexture`).
4. Color space / transfer functions — `LUTColorSpace`, `LUTColorTransferFunction`, `LUTColorSpaceWhitePoint`.
5. Rendering and platform glue — `GPUImageCocoaLUTFilter`, Core Image wrappers (`processCIImage:`), SceneKit preview (`LUTPreviewScene`). These require platform APIs and may remain behind conditional compilation.
6. Misc/tools/documentation — helper utilities, metadata formatter, sample assets.

Port checklist (file / primary symbols / top methods/properties to port)
Below is a file-by-file mapping derived from the repository headers. For each symbol, port the listed properties/methods (initial public surface). Implementation details live in .m files — port behavior, not line-by-line code.

Core

- `Classes/LUT.h` -> Swift: `final class LUT`
  - properties: `title: String?`, `descriptionText: String?`, `size: Int`, `inputLowerBound: Double`, `inputUpperBound: Double`, `metadata: [String: Any]`, `passthroughFileOptions: [String: Any]?`
  - factory/read/write: `static func from(url: URL) throws -> LUT`, `static func from(data: Data, formatterID: String?) -> LUT?`, `func dataRepresentation() -> Data`, `func write(to url: URL, formatterID: String?, options: [String:Any]?, conformLUT: Bool) throws`
  - initializers: `init(size: Int, inputLowerBound: Double, inputUpperBound: Double)`
  - lattice iteration: `func loop(_ block: (Int,Int,Int) -> Void)` (port `-LUTLoopWithBlock:`)
  - transformations: `func resized(to newSize: Int) -> LUT`, `func combined(with other: LUT) -> LUT`, `func clamped(lower: Double, upper: Double) -> LUT`, `func offset(with color: LUTColor) -> LUT`, `func remapped(...) -> LUT`, `func changingStrength(_ strength: Double) -> LUT`, `func inverted() -> LUT`, equality checks and error metrics
  - CoreImage: `func coreImageFilter(colorSpace: CGColorSpace?) -> CIFilter?`, `func process(ciImage: CIImage) -> CIImage?`

- `Classes/LUTColor.h` -> Swift: `struct LUTColor` (value type)
  - properties: `var red: Double`, `var green: Double`, `var blue: Double`
  - constructors: `static func color(red: Double, green: Double, blue: Double) -> LUTColor`, `static func zeros()`, `static func ones()`, `static func fromIntegers(bitDepth: Int, r:Int, g:Int, b:Int) -> LUTColor`
  - utilities: `func rgbArray() -> [Double]`, `func luminanceRec709() -> Double`, `func minValue()/maxValue()`, `func clamped01() -> LUTColor`, `func remapped(...) -> LUTColor`, `func applyingColorMatrix(_ m: [Double]) -> LUTColor`, arithmetic ops: `multiplied(by:)`, `added(_:)`, `lerp(to:amount:)`, `distance(to:)`, `systemColor` bridging for platforms

- `Classes/LUT1D.h` -> Swift: `final class LUT1D: LUT` or specialized struct depending on design
  - factories: `static func with(redCurve: [Double], greenCurve: [Double], blueCurve: [Double], lowerBound: Double, upperBound: Double) -> LUT1D`
  - queries: `func value(atR r: Int) -> Double` etc., `func rgbCurveArray() -> [[Double]]`, `func isReversible(strict: Bool) -> Bool`, `func reversed(strictness: Bool, autoAdjustInputBounds: Bool) -> LUT1D`, `func to3D(size: Int) -> LUT`

- `Classes/LUT3D.h` -> Swift: `final class LUT3D: LUT`
  - transformations: `func applyingFalseColor() -> LUT3D`, `func extractingColorShift(strictness: Bool) -> LUT3D`, `func extractingContrastOnly() -> LUT3D`, `func convertingToMono(method:) -> LUT3D`, `func swizzle1DChannels(method:strictness:) -> LUT3D`, `func applyColorMatrix(...) -> LUT3D`, `func toLUT1D() -> LUT1D`

Processing & Actions

- `Classes/LUTProcessor.h` -> Swift: `class LUTProcessor` (base for long-running tasks)
  - properties: `lut: LUT`, `progressDescription: String?`, `completionHandler: ((LUT?) -> Void)?`, `cancelHandler: (() -> Void)?`, `progress: Float`, `cancelled: Bool`
  - functions: `class func processor(for lut: LUT, completion: @escaping (LUT)->Void, cancel: @escaping ()->Void) -> LUTProcessor`, `func cancel()`, `func process()` (override), `func completed(with lut: LUT)`, `func checkCancellation() -> Bool`, `func didCancel()`

- `Classes/LUTReverser.h` -> Swift: `class LUTReverser: LUTProcessor` (port subclass behavior)

- `Classes/LUTAction.h` -> Swift: `struct or class LUTAction` with an action block/closure and factory helpers matching Objective‑C convenience constructors (port named constructors listed in header).

Formatters (IO)

All formatters subclass `LUTFormatter`. Port `LUTFormatter` as a protocol or base class, and port each format as a concrete type implementing read/write.

- `Classes/LUTFormatter.h` -> Swift: `protocol LUTFormatter` or `class LUTFormatter` with static discovery functions:
  - discovery: `static func formatters(for fileExtension: String) -> [LUTFormatter.Type]`, `static func formatter(with id: String) -> LUTFormatter.Type?`, `static func validReader(for url: URL) -> LUTFormatter.Type?` etc.
  - IO: `func lut(from url: URL) throws -> LUT`, `func lut(from data: Data) throws -> LUT`, `func data(from lut: LUT, options: [String:Any]?) throws -> Data`, `func string(from lut: LUT, options: [String:Any]?) -> String`.

Port subclasses (create a Swift type per header) — initial list (these are mostly empty subclass declarations):
  - `LUTFormatter3DL`
  - `LUTFormatterArriLook`
  - `LUTFormatterCMSTestPattern`
  - `LUTFormatterClipster`
  - `LUTFormatterCube`
  - `LUTFormatterDaVinciDAVLUT`
  - `LUTFormatterDiscreet1DLUT`
  - `LUTFormatterFSIDAT`
  - `LUTFormatterHaldCLUT`
  - `LUTFormatterILUT`
  - `LUTFormatterImageBased`
  - `LUTFormatterMatchLight`
  - `LUTFormatterNucodaCMS`
  - `LUTFormatterOLUT`
  - `LUTFormatterQuantel`
  - `LUTFormatterResolveDAT`
  - `LUTFormatterUnwrappedTexture`

Platform-specific headers to consider
- `CocoaLUT.h` — central macros and platform typedefs (SystemColor alias), suggested LUT size constants. Useful for platform mapping and shared constants.
- `GPUImageCocoaLUTFilter.h` — GPUImage integration (iOS/macOS) — keep as a shim or port later when replacing GPUImage dependency.
- `osx/LUT1DGraphView.h` — OS X preview UI (AppKit). Port to SwiftUI/NSView-based module if desired, but low priority.
- `osx/LUTFormatterICCProfile.h` — ICC profile based formatter (OS X only). Port or keep as bridged Objective‑C depending on CGColorSpace needs.
- `osx/LUTPreviewImageGenerator.h` — OS X image preview generation helper.
- `osx/LUTPreviewView.h` — OS X preview view.


Color spaces & transfer

- `Classes/LUTColorSpace.h` -> Swift: `final class LUTColorSpace`
  - properties and factories: port chromaticities, npm matrix, name, known predefined color spaces and conversion functions: `convert(lut:from:to:useBradfordMatrix:)` and matrix helpers.

- `Classes/LUTColorSpaceWhitePoint.h` -> Swift: struct/class with `whiteChromaticityX`, `whiteChromaticityY`, factories like `whitePoint(fromColorTemperature:)`, `d65()`, and `tristimulusValues()`.

- `Classes/LUTColorTransferFunction.h` -> Swift: port `LUTColorTransferFunction` with factories for linear/gamma and transform helpers.

Helpers & Metadata

- `Classes/LUTHelper.h` -> port free functions as static helpers in `LUTHelper` Swift type (or free functions in a `Helpers.swift` file): clamping, remap, loops (LUTLoop equivalents), `isLUT1D`, `isLUT3D`, `LUTAsLUT1D`, etc.

- `Classes/LUTMetadataFormatter.h` -> port metadata parsing helpers.

Rendering & platform

- `Classes/GPUImageCocoaLUTFilter.h` -> Swift: this depends on GPUImage (external). Provide a Swift adapter that can either depend on the GPUImage Swift module or remain as an Objective‑C shim until GPUImage usage is replaced. Port `init(with lut: LUT)` behavior and lookup image creation.

- `Classes/LUTPreviewScene.h` -> SceneKit-based preview. Port as a separate module `CocoaLUTSwift/Preview` guarded with `#if canImport(SceneKit)`.

Tests: what to port first
- Port `Tests/` cases that exercise core LUT math and IO. Create equivalent tests in Swift verifying:
  - roundtrip read/write for `.cube` and `.3dl` with sample files in `Assets/TransferFunctionLUTs/`.
  - color conversion routines produce expected numeric results for sample vectors.
  - LUT resizing/combining produces expected lattice values for small sizes (3–5) to make assertions easy.

AI agent instructions (explicit steps)
1. Continue working on the current branch (`swift`) and keep TDD discipline.
2. Port `LUTFormatterICCProfile` to Swift, covering both read and write paths with fixture-based tests.
3. Port the macOS preview stack (`LUTPreviewScene`, `LUTPreviewImageGenerator`, `LUTPreviewView`, `LUT1DGraphView`) to Swift (SwiftUI/AppKit as appropriate) and add smoke tests that validate image generation.
4. Introduce a Swift formatter registry that mirrors the Objective‑C `LUTFormatter` discovery API and expose convenience `LUT` read/write helpers that delegate to it.
5. Replace `CocoaLUT.h` macros with Swift constants/types inside `CocoaLUT_swift.swift` (suggested sizes, `SystemColor` typealias, etc.).
6. Remove or reimplement the legacy Objective‑C `LUTFormatterImageBased` scaffolding once equivalent Swift utilities cover its behavior.
7. Update README/API docs after the above tasks to document the Swift-first entry points and Objective‑C compatibility story.

Notes and constraints
- Preserve numeric behavior: unit tests must assert numerics to reasonable tolerances (use `XCTAssertEqualWithAccuracy` / `XCTAssertEqual` with tolerance).
- Performance: when porting heavy loops (trilinear interpolation over lattices), prefer to write idiomatic Swift but verify performance. Consider `withUnsafeMutableBufferPointer` and C-style loops only where needed.
- Interop: keep an Objective‑C compatibility layer (small bridging header) for consumers that still import `CocoaLUT` via CocoaPods. The end goal is to provide a pure Swift package.

## Audit log

- 2025-10-29: Reviewed headers in `Classes/` and `Classes/osx/`; confirmed every public symbol is already mapped in this plan. No new Objective-C sources require additional tasks. Added explicit progress checklist to track TDD-aligned milestones.
- 2025-10-30: Resolved swizzle regression by porting direct 1D inverse lookup; tightened tests to ensure LUTAction swizzle matches manual composition. Next focus: implement color-temperature action and supporting color space/white point utilities.
- 2025-10-30: Confirmed parity against Objective-C by switching to high-resolution curve inversion; `testSwizzleActionMatchesManualComposition` now green.
- 2025-10-31: Replaced the Objective-C image-based formatter scaffolding with Swift platform bridges, added NSImage round-trip coverage, and updated plan status accordingly.
- 2025-10-31: Kicked off concurrency annotation cleanup by isolating `LUT1DGraphViewTests` to `@MainActor` and confirming the suite passes under `-strict-concurrency=complete`.
- 2025-10-31: Scoped preview and ICC profile test suites to `@MainActor` to unblock strict concurrency warnings; full package still green under `-strict-concurrency=complete`.
- 2025-10-31: Extended MainActor isolation to SceneKit/Core Image preview tests and Swift Testing suites (`LUTPreviewSceneTests`, `LUTPlatformGlueTests`, `LUTFormatterCMSTestPatternTests.nsImageRoundTrip`); verified strict-concurrency run remains clean.
- 2025-10-31: Annotated `Sources/CocoaLUT-swift/LUTPreviewScene` with `@MainActor` to align runtime isolation with its preview tests; reconfirmed `swift test -Xswiftc -strict-concurrency=complete` stays green.
- 2025-10-31: Scoped `Sources/CocoaLUT-swift/LUT1DGraphView` to `@MainActor` to match AppKit-only usage and keep the strict-concurrency suite warning-free.
- 2025-10-31: Marked AppKit platform glue (`LUTPlatformGlue`, `ImageBasedFormatterPlatformBridge`) and NSImage formatter helpers as `@MainActor`; strict-concurrency test suite (`swift test -Xswiftc -strict-concurrency=complete`) remains fully green (180 XCTest + 10 Swift Testing cases).
- 2025-10-31: Finished the preview pipeline pass by placing `@MainActor` on platform glue helpers (`LUTPlatformGlue`, `ImageBasedFormatterPlatformBridge`, `LUTFormatter{HaldCLUT,UnwrappedTexture,CMSTestPattern}`, `LUT1DGraphView`); reran `swift test -Xswiftc -strict-concurrency=complete` with 180 XCTest + 10 Swift Testing cases passing.
- 2025-10-31: Updated `README.md` for the Swift-first workflow (SwiftPM installation, usage examples, maintenance note for CocoaPods) to close out the documentation task.

Appendix — formatters and small headers (quick map)
- Files that are subclasses of `LUTFormatter` and should be ported as concrete formatter types (implement `read`, `write`):
  - `LUTFormatter3DL.h`, `LUTFormatterCube.h`, `LUTFormatterHaldCLUT.h`, `LUTFormatterUnwrappedTexture.h`, `LUTFormatterImageBased.h`, `LUTFormatterILUT.h`, `LUTFormatterDiscreet1DLUT.h`, `LUTFormatterFSIDAT.h`, `LUTFormatterQuantel.h`, `LUTFormatterResolveDAT.h`, `LUTFormatterNucodaCMS.h`, `LUTFormatterDaVinciDAVLUT.h`, `LUTFormatterArriLook.h`, `LUTFormatterClipster.h`, `LUTFormatterCMSTestPattern.h`, `LUTFormatterMatchLight.h`, `LUTFormatterOLUT.h`

---
If you'd like, I can now:
- Generate the initial Swift type files for `LUTColor`, `LUT`, and `LUTHelper` (with basic tests) and run `swift test` locally (if you want me to run the tests in this environment).
- Or, produce a more detailed per-method port list by parsing every `.h` and `.m` file and extracting method signatures (I can do this next and create a CSV/MD table).

Tell me which next step you want: scaffold core Swift types + tests now, or a full signature extraction for all files first?
