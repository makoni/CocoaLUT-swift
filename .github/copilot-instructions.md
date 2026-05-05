## Copilot instructions for CocoaLUT-swift

Purpose: give an AI coding agent the minimal, high-value knowledge to be productive in this repo.

- Big picture
  - Core implementation is Objective‑C and lives in `Classes/`. This is the canonical data model and format handling (see `LUT.h`, `LUTColor.*`, `LUTFormatter*.m`).
  - A small Swift Package wrapper lives in `Sources/CocoaLUT-swift/` and exposes a Swift target (`Package.swift`). Use SPM for Swift-only iterations.
  - Tests and Xcode projects are in `Tests/` (includes `CocoaLUTTests.xcworkspace`/project). Assets and sample LUT files are in `Assets/TransferFunctionLUTs/`.

- Key files to inspect for any task
  - `Classes/LUT.h` — primary API: lattice size, bounds, factory methods like `+LUTFromURL:` and immutable-style `LUTBy...` transforms.
  - `Classes/LUTProcessor.m` — long-running processing patterns, cancellation, progress reporting.
  - `Classes/LUTFormatter*.m` — one file per format (Cube, 3DL, Hald, etc.). Add new formats by following existing formatter patterns.
  - `Classes/GPUImageCocoaLUTFilter.m` — how LUTs are converted to GPUImage lookup filters (guarded by `COCOAPODS_POD_AVAILABLE_GPUImage`).
  - `Classes/LUTFormatterUnwrappedTexture.*` — converts 3D LUTs into images used by GPU pipelines.
  - `Sources/CocoaLUT-swift/CocoaLUTSwift.swift` — Swift wrapper entry points.

- Project-specific conventions and patterns
  - Formatters follow a per-file class model: `LUTFormatter<Name>.m` implementing parsing and exporter logic. Search `LUTFormatter` implementations to model new parsers.
  - Immutable-style transformation naming: methods named `LUTBy...` return a new LUT instance rather than mutating the receiver.
  - Lattice iteration helper: `-LUTLoopWithBlock:` is the canonical way to iterate 3D indices of the LUT lattice.
  - Metadata is stored in `metadata` (an `NSMutableDictionary`). File-specific options are stored in `passthroughFileOptions` (do not mutate after set).
  - Objective‑C APIs use factory class methods (e.g., `+LUTFromURL:`) and conform to `NSCopying`/`NSCoding` where applicable.
  - Conditional compilation: GPUImage integration and some features are enabled only when built via CocoaPods (macro `COCOAPODS_POD_AVAILABLE_GPUImage`).

- Build & test workflows (practical)
  - Swift-only quick build/tests: `swift build` and `swift test` (works against the Swift package target `CocoaLUT-swift`).
  - For full Objective‑C features and GPUImage support, use CocoaPods and Xcode:

    ```bash
    cd /path/to/CocoaLUT-swift
    pod install      # enables GPUImage/CocoaPods macros
    open Tests/CocoaLUTTests.xcworkspace
    ```

  - Use Xcode to run the ObjC unit tests / integration tests. SPM tests may not exercise ObjC-only code that relies on CocoaPods.

- Common integration points to keep in mind
  - Core Image: many APIs return `CIFilter` (see `-coreImageFilterWithColorSpace:` and `-processCIImage:`).
  - GPUImage: `GPUImageCocoaLUTFilter` wraps a LUT as a lookup image — see `GPUImageCocoaLUTFilter.m` for the exact steps to convert a `LUT` to a `GPUImagePicture` and `GPUImageLookupFilter`.
  - Formatters: add new file readers/writers in `Classes/` using the naming and registration conventions used by existing `LUTFormatter*` classes.

- Concrete examples (search these symbols when implementing features)
  - Load a LUT from disk: `+LUTFromURL:` (see `Classes/LUT.h`).
  - Apply a LUT to a `CIImage`: `-processCIImage:` / `-coreImageFilterWithCurrentColorSpace`.
  - Convert LUT → GPUImage filter: see `-initWithLUT:` in `Classes/GPUImageCocoaLUTFilter.m`.
  - Long-running reversal/processing patterns: `LUTProcessor` exposes `process`, `cancel`, `completedWithLUT:` and a `checkCancellation` helper.

- Where to look next when asked to implement or change behavior
  - Adding a LUT format: copy an existing `LUTFormatter<Format>.m` pair and adapt parsing/writing; register/inspect formatter discovery in the codebase.
  - Performance changes: inspect `LUTLoopWithBlock:` usage, `LUTProcessor.m`, and image conversion code in `LUTFormatterUnwrappedTexture`.
  - Cross-platform / conditional features: search for `TARGET_OS_IPHONE`, `TARGET_OS_MAC`, and `COCOAPODS_POD_AVAILABLE_GPUImage` to understand platform-only code paths.

- Feedback / follow-ups
  If anything in these instructions is unclear or you want extra examples (small code snippets showing common calls, or a short checklist for adding a new formatter), tell me which area to expand and I will update this file.
