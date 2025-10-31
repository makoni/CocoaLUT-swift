## Copilot instructions for CocoaLUT-swift

Purpose: give an AI coding agent the minimal, high-value knowledge to be productive in this repo.

- Big picture
  - The Swift package in `Sources/CocoaLUT-swift/` is the canonical implementation. It contains the formatter registry, color science utilities, processors, Core Image glue, preview helpers, and optional GPUImage adapter.
  - LUT assets used by unit tests live in `Assets/TransferFunctionLUTs/` and are processed by SwiftPM resource bundles.
  - Tests are written in both XCTest (`Tests/CocoaLUTSwiftTests/`) and the new Swift Testing suite (`Tests/CocoaLUT-swiftTests/`). There is no remaining Objective-C code.

- Key files to inspect for any task
  - `LUT.swift`, `LUT1D.swift`, `LUT3D.swift`: core lattice structures and transformations.
  - `LUTColor.swift`, `LUTColorSpace.swift`, `LUTColorTransferFunction.swift`, `LUTColorSpaceWhitePoint.swift`: color math and conversions.
  - `LUTFormatterRegistry.swift` plus `LUTFormatter*.swift` files: formatter registration and read/write logic for each supported format.
  - `LUTProcessor.swift`, `LUTAction.swift`, `LUTReverser.swift`, `LUTRecipe.swift`: processing pipeline, actions, and long-running operations.
  - `CocoaLUT_swift.swift`: top-level facade with convenience APIs that mirror the legacy Objective-C surface.
  - `GPUImageCocoaLUTFilter.swift`: optional GPUImage integration guarded by `canImport(GPUImage)` checks.
  - `LUTPreviewScene.swift`, `LUTPreviewImageGenerator.swift`, `LUTPreviewView.swift`, `LUT1DGraphView.swift`: macOS/iOS preview utilities (mostly `@MainActor`).

- Project-specific conventions and patterns
  - Formatters register themselves through `LUTFormatterRegistry` using `LUTFormatterDescriptor` metadata and `LUTFormatterIdentifier` enum cases.
  - Public APIs prefer value semantics where practical (`LUTColor`, `LUTAction` inputs) and return new instances rather than mutating in place.
  - Platform-specific work (AppKit, UIKit, SceneKit) is wrapped in `@MainActor` types to keep strict concurrency checking clean.
  - GPUImage support is optional. All entry points are conditionally compiled, so guard new code with the same `canImport(GPUImage)` checks.

- Build & test workflows (practical)
  - Use `swift build` and `swift test -Xswiftc -strict-concurrency=complete` locally. Both XCTest and Swift Testing suites run through SwiftPM.
  - No CocoaPods workspace or Objective-C targets remain. The `CocoaLUT.podspec` simply exposes the Swift sources for legacy consumers.
  - When adding new resources for tests, include them in the relevant target’s `Resources/` directory or update the SwiftPM resource manifest accordingly.

- Common integration points to keep in mind
  - Core Image: check `LUT.process(ciImage:)`, `LUT.coreImageFilter(colorSpace:)`, and helpers in `LUTPlatformGlue.swift`.
  - GPUImage: see `GPUImageCocoaLUTFilter.swift` for constructing lookup filters from Swift LUTs.
  - SceneKit/AppKit previews: `LUTPreviewScene` provides point cloud previews; `LUTPreviewImageGenerator` renders 2D imagery.

- Where to look next when asked to implement or change behavior
  - Adding a LUT format: implement a new `LUTFormatter<Format>.swift`, register it in `LUTFormatterRegistry`, and add regression tests under `Tests/CocoaLUTSwiftTests/` plus Swift Testing coverage if appropriate.
  - Performance tuning: start with core loops in `LUT.swift`/`LUT3D.swift` and helper functions in `LUTHelper.swift`.
  - UI/preview updates: look at the `@MainActor` preview files and ensure platform availability checks remain intact (see existing `canImport(AppKit)` / `canImport(UIKit)` guards).

- Feedback / follow-ups
  If anything in these instructions is unclear or you want extra examples (small code snippets showing common calls, or a short checklist for adding a new formatter), tell me which area to expand and I will update this file.
