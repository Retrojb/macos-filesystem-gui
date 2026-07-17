# Implementation Plan: macOS Desktop App Scaffold

## Overview

Create a minimal macOS desktop application scaffold using Swift and SwiftUI, managed by Swift Package Manager. The application launches a native window with standard lifecycle handling and a menu bar, built entirely from the command line without an Xcode project file.

## Tasks

- [x] 1. Set up SPM project structure and package manifest
  - [x] 1.1 Create Package.swift with executable target
    - Create the `Package.swift` file at the project root declaring swift-tools-version 5.9, a `RetroFilesystemGUI` executable target, and macOS v14 as the platform
    - Create the `Sources/RetroFilesystemGUI/` directory structure
    - _Requirements: 4.1, 4.3, 4.4, 5.1, 5.3_

- [x] 2. Implement application entry point and lifecycle
  - [x] 2.1 Create the SwiftUI App entry point (`RetroFilesystemGUIApp.swift`)
    - Implement a `@main` struct conforming to the `App` protocol
    - Declare a `WindowGroup` scene containing `ContentView`
    - Set default window size to 800x600 using `.defaultSize()` and `.frame(minWidth:minHeight:)`
    - Wire in the `NSApplicationDelegateAdaptor` for the `AppDelegate`
    - _Requirements: 1.1, 1.4, 5.2_

  - [x] 2.2 Create the AppDelegate (`AppDelegate.swift`)
    - Implement `NSApplicationDelegate` as an `NSObject` subclass
    - In `applicationDidFinishLaunching`, set activation policy to `.regular` and activate the app
    - Return `true` from `applicationShouldTerminateAfterLastWindowClosed` so the app exits when the window closes
    - In `applicationShouldTerminate`, schedule a 5-second force-termination fallback via `DispatchQueue.global().asyncAfter` calling `exit(0)`, then return `.terminateNow`
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 3. Implement the main content view
  - [x] 3.1 Create ContentView (`ContentView.swift`)
    - Implement a SwiftUI `View` struct as the root view for the main window
    - Display the application title text ("Retro Filesystem GUI") as placeholder content
    - Use `.frame(maxWidth: .infinity, maxHeight: .infinity)` to fill the window
    - _Requirements: 1.1, 1.2, 5.2_

- [x] 4. Checkpoint - Verify build and launch
  - Ensure `swift build` completes with exit code 0 and `swift run` launches the app with a visible window. Ask the user if questions arise.

- [x] 5. Verify menu bar and window behavior
  - [x] 5.1 Confirm menu bar configuration
    - Verify that SwiftUI's default `WindowGroup` provides the application menu titled "RetroFilesystemGUI", a Quit item with Cmd+Q, and an Edit menu with Cut/Copy/Paste
    - Add a `.commands {}` modifier to the scene for future extensibility
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 6. Final checkpoint - Full integration verification
  - Ensure `swift build` exits with code 0, `swift run` launches and displays the window, closing the window terminates the app, and Cmd+Q quits. Ask the user if questions arise.

## Notes

- No property-based tests are included — the scaffold has no pure functions or data transformations suitable for PBT
- Testing is manual: verify build success, window appearance, lifecycle behavior, and menu items
- The project does not include an Xcode project file; developers open `Package.swift` directly in Xcode or build from the CLI
- No code signing, entitlements, or distribution packaging is included — this is a local development scaffold
- Each task references specific requirements for traceability

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1", "2.2", "3.1"] },
    { "id": 2, "tasks": ["5.1"] }
  ]
}
```
