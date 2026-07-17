# Implementation Plan: Enhanced File Management

## Overview

This plan implements four integrated capabilities: sorting rules with unsorted file detection, directory comparison, file alias names, and a JSON metadata panel. Tasks are structured to build data models and services first, then ViewModels, then views, wiring everything together incrementally. Property-based tests validate correctness properties from the design document.

## Tasks

- [x] 1. Set up data models and validation types
  - [x] 1.1 Create SortingRule, SortingRulesStore, and validation types
    - Create `Sources/RetroFilesystemGUI/Models/SortingRule.swift`
    - Define `SortingRuleType` enum (fileExtension, namePattern, tag) with `Codable` and `Equatable`
    - Define `SortingRule` struct with id, ruleType, pattern, createdDate
    - Define `DirectorySortingRules` struct with directoryPath and rules array
    - Define `SortingRulesStore` struct with directories array
    - Define `SortingRuleValidationError` enum (emptyPattern, patternTooLong, maxRulesReached)
    - _Requirements: 1.1, 1.2, 1.3, 1.6_

  - [x] 1.2 Create ComparisonResult and ComparisonItem models
    - Create `Sources/RetroFilesystemGUI/Models/ComparisonResult.swift`
    - Define `ComparisonItem` struct with id, name, size, modificationDate, isDirectory, sourceURL
    - Define `ComparisonResult` struct with directory names, URLs, and three item arrays (uniqueToFirst, uniqueToSecond, inBoth)
    - _Requirements: 3.1, 3.2, 3.4_

  - [x] 1.3 Create AliasStore model and validation types
    - Create `Sources/RetroFilesystemGUI/Models/AliasStore.swift`
    - Define `AliasStore` struct with `aliases: [String: String]` dictionary, `Codable` and `Equatable`
    - Define `AliasValidationError` enum (empty, tooLong, containsSlash, containsColon)
    - _Requirements: 4.1, 4.8, 4.9_

  - [x] 1.4 Create MetadataStore and JSONValue models
    - Create `Sources/RetroFilesystemGUI/Models/MetadataStore.swift`
    - Define `JSONValue` enum with cases: null, bool, int, double, string, array, object
    - Implement custom `Codable` conformance for `JSONValue` (encode/decode arbitrary JSON)
    - Define `MetadataStore` struct with `entries: [String: JSONValue]` dictionary
    - Define `MetadataValidationError` enum (malformedJSON with line/character, tooLarge)
    - _Requirements: 5.1, 6.1, 6.2, 6.6, 6.9_

- [x] 2. Implement storage services
  - [x] 2.1 Create SortingRulesStorageService with protocol
    - Create `Sources/RetroFilesystemGUI/Services/SortingRulesStorageService.swift`
    - Define `SortingRulesStorageServiceProtocol` with load/save methods
    - Implement concrete `SortingRulesStorageService` following `TagStorageService` pattern
    - Use `~/Library/Application Support/RetroFilesystemGUI/sorting-rules.json`
    - Handle missing file (create empty), malformed JSON (log + return empty), write errors (propagate)
    - Use `JSONEncoder` with `.prettyPrinted` and `.sortedKeys`, atomic writes
    - Support custom `storageURL` init for testing
    - _Requirements: 1.2, 1.5, 1.7, 7.1_

  - [ ]* 2.2 Write property tests for SortingRulesStore (Properties 1, 3, 4, 15)
    - **Property 1: SortingRulesStore round-trip** — Encode then decode produces equal store
    - **Property 3: Sorting rule cap invariant** — Never exceed 50 rules per directory
    - **Property 4: Invalid sorting rule pattern rejection** — Empty/too-long patterns rejected
    - **Property 15: Sorting rule deletion** — Deleting a rule decreases count by one, removes only that rule
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.6, 7.1**

  - [x] 2.3 Create AliasStorageService with protocol
    - Create `Sources/RetroFilesystemGUI/Services/AliasStorageService.swift`
    - Define `AliasStorageServiceProtocol` with load/save methods
    - Implement concrete `AliasStorageService` following same pattern
    - Use `~/Library/Application Support/RetroFilesystemGUI/aliases.json`
    - Handle missing file, malformed JSON, write errors identically to TagStorageService
    - Use `JSONEncoder` with `.prettyPrinted` and `.sortedKeys`, atomic writes
    - _Requirements: 4.1, 4.7, 4.9, 7.2, 7.4_

  - [ ]* 2.4 Write property tests for AliasStore (Properties 6, 8)
    - **Property 6: AliasStore round-trip** — Encode then decode produces equal store
    - **Property 8: Invalid alias name rejection** — Empty, >255 chars, contains '/' or ':' rejected
    - **Validates: Requirements 4.8, 4.9, 7.2, 7.4, 7.8**

  - [x] 2.5 Create MetadataStorageService with protocol
    - Create `Sources/RetroFilesystemGUI/Services/MetadataStorageService.swift`
    - Define `MetadataStorageServiceProtocol` with load/save methods
    - Implement concrete `MetadataStorageService` following same pattern
    - Use `~/Library/Application Support/RetroFilesystemGUI/metadata.json`
    - Handle missing file, malformed JSON, write errors
    - Use `JSONEncoder` with `.prettyPrinted` and `.sortedKeys`, atomic writes
    - _Requirements: 6.5, 6.6, 7.1, 7.3, 7.5, 7.6_

  - [ ]* 2.6 Write property tests for MetadataStore (Properties 10, 11, 12)
    - **Property 10: MetadataStore round-trip** — Encode then decode produces equal store
    - **Property 11: Metadata save then undo** — Save V2 then undo restores V1
    - **Property 12: Stale metadata cleanup** — Non-existent paths removed after refresh
    - **Validates: Requirements 6.4, 6.6, 6.7, 7.1, 7.3, 7.7**

  - [x] 2.7 Create DirectoryComparatorService with protocol
    - Create `Sources/RetroFilesystemGUI/Services/DirectoryComparatorService.swift`
    - Define `DirectoryComparatorServiceProtocol` with compare method
    - Implement comparison by listing immediate children of both directories via `FileSystemServiceProtocol`
    - Partition into uniqueToFirst, uniqueToSecond, inBoth by case-sensitive name matching
    - Handle permission errors and missing directories with descriptive errors
    - _Requirements: 3.1, 3.2, 3.6, 3.8_

  - [ ]* 2.8 Write property tests for DirectoryComparatorService (Property 5)
    - **Property 5: Directory comparison three-way partition** — Union of all categories equals union of inputs, no duplicates within categories
    - **Validates: Requirements 3.1, 3.2**

- [x] 3. Checkpoint - Ensure all model and service tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement utility functions and unsorted file evaluation
  - [x] 4.1 Implement unsorted file evaluation logic
    - Create `Sources/RetroFilesystemGUI/Utilities/UnsortedFileEvaluator.swift`
    - Implement function that takes a list of `FileItem` and `[SortingRule]` and returns unsorted items
    - Extension matching: compare file extension case-insensitively (without dot)
    - Name pattern matching: glob matching via `NSPredicate` with LIKE operator or `fnmatch`
    - Tag matching: check if file path has the specified tag via `TagStorageService`
    - A file is sorted if it matches at least one rule; unsorted if it matches none
    - If no rules exist for directory, all files are considered sorted
    - _Requirements: 1.3, 2.2, 2.6_

  - [ ]* 4.2 Write property tests for unsorted file evaluation (Property 2)
    - **Property 2: Unsorted file evaluation correctness** — File is unsorted iff it matches no rule
    - **Validates: Requirements 1.3, 2.2, 2.6**

  - [x] 4.3 Implement badge formatting function
    - Create `Sources/RetroFilesystemGUI/Utilities/BadgeFormatter.swift`
    - Return string representation for 1–99, "99+" for >99, nil for 0
    - _Requirements: 2.1_

  - [ ]* 4.4 Write property test for badge formatting (Property 14)
    - **Property 14: Badge text formatting** — Correct output for all non-negative integers
    - **Validates: Requirements 2.1**

  - [x] 4.5 Implement path truncation function
    - Create `Sources/RetroFilesystemGUI/Utilities/PathTruncation.swift`
    - If path ≤ 80 characters: return unchanged
    - If path > 80 characters: return "…" + rightmost 79 characters (total 80)
    - _Requirements: 5.6_

  - [ ]* 4.6 Write property test for path truncation (Property 13)
    - **Property 13: Path truncation** — Output ≤ 80 chars, preserves rightmost characters
    - **Validates: Requirements 5.6**

  - [x] 4.7 Implement alias validation function
    - Add validation function (can be in AliasStore or a standalone utility)
    - Check: empty → .empty, >255 chars → .tooLong, contains '/' → .containsSlash, contains ':' → .containsColon
    - _Requirements: 4.8_

  - [x] 4.8 Implement metadata JSON validation function
    - Add validation function for metadata content
    - Check: parse JSON, report first error line/character if malformed; check size ≤ 1 MB
    - _Requirements: 6.1, 6.2, 6.9_

- [x] 5. Checkpoint - Ensure all utility tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement ViewModels
  - [x] 6.1 Create SortingRulesViewModel
    - Create `Sources/RetroFilesystemGUI/ViewModels/SortingRulesViewModel.swift`
    - `@Observable` class with rules array, editingRule, validationError, directoryPath
    - Methods: loadRules, addRule, deleteRule, updateRule
    - Validate pattern on add/update (reject empty, too-long patterns, cap at 50 rules)
    - Persist changes via `SortingRulesStorageServiceProtocol`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6_

  - [x] 6.2 Create DirectoryComparisonViewModel
    - Create `Sources/RetroFilesystemGUI/ViewModels/DirectoryComparisonViewModel.swift`
    - `@Observable` class with comparisonResult, isComparing, errorMessage
    - Method: compare(directory1:directory2:) that validates exactly 2 directories, checks accessibility
    - Uses `DirectoryComparatorServiceProtocol` and `FileSystemServiceProtocol`
    - Handle permission errors and missing directory errors with user-facing messages
    - _Requirements: 3.1, 3.5, 3.6, 3.9_

  - [x] 6.3 Extend FileManagerViewModel with alias support
    - Add `aliasStore` property loaded via `AliasStorageServiceProtocol` on init
    - Add `aliasStorageService` dependency (inject in init)
    - Implement `setAlias(for:name:)` with validation, returning Result
    - Implement `removeAlias(for:)` removing from store and persisting
    - Implement `displayName(for:)` returning alias if present, otherwise filesystem name
    - Implement `isAliased(_:)` for italic styling decision
    - Add stale alias cleanup in `refreshContents()` — remove entries where path no longer exists
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 4.6, 4.8_

  - [ ]* 6.4 Write property tests for alias display name resolution and stale cleanup (Properties 7, 9)
    - **Property 7: Display name resolution** — Returns alias if present, filesystem name otherwise; assign then remove restores original
    - **Property 9: Stale alias cleanup** — After refresh, only existing paths remain
    - **Validates: Requirements 4.2, 4.4, 4.6**

  - [x] 6.5 Extend FileManagerViewModel with metadata panel support
    - Add `metadataStorageService` dependency (inject in init)
    - Add `metadataPanelVisible`, `selectedItemMetadata`, `metadataValidationError`, `previousMetadataState` properties
    - Implement `loadMetadata(for:)` — load from store, pretty-print as 2-space JSON string
    - Implement `saveMetadata(jsonText:for:)` — validate JSON, check size ≤ 1 MB, persist
    - Implement `undoMetadata(for:)` — restore previousMetadataState if available
    - Add stale metadata cleanup in `refreshContents()` — remove entries for non-existent paths
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.7, 6.8, 6.9_

  - [x] 6.6 Extend FileManagerViewModel with unsorted file tracking
    - Add `sortingRulesService` dependency
    - Add `unsortedCounts: [String: Int]` dictionary and `unsortedFilterActive` flag
    - Implement `evaluateUnsortedFiles(in:)` using `UnsortedFileEvaluator`
    - Call evaluation on `loadContents()` and `refreshContents()` for directories with rules
    - Implement `toggleUnsortedFilter(for:)` to filter/unfilter view
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [x] 7. Checkpoint - Ensure ViewModel tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement views
  - [x] 8.1 Create SortingRulesEditor view
    - Create `Sources/RetroFilesystemGUI/Views/SortingRulesEditor.swift`
    - Sheet presenting a form for adding/editing/deleting sorting rules
    - Rule type picker (extension, name pattern, tag)
    - Pattern text field with inline validation error display
    - List of existing rules with swipe-to-delete
    - Wire to `SortingRulesViewModel`
    - _Requirements: 1.1, 1.4, 1.6_

  - [x] 8.2 Create SortStatusBadge view
    - Create `Sources/RetroFilesystemGUI/Views/SortStatusBadge.swift`
    - Overlay badge showing unsorted count using `BadgeFormatter`
    - Tappable to toggle unsorted filter
    - Display consistently across icon grid, list, and column view modes
    - _Requirements: 2.1, 2.3, 2.4, 2.7_

  - [x] 8.3 Create ComparisonWindow view
    - Create `Sources/RetroFilesystemGUI/Views/ComparisonWindow.swift`
    - Standalone window with three labeled sections
    - Section headers: "Only in [name]" and "In Both"
    - Each item shows file name, human-readable size (bytes/KB/MB/GB), and locale-formatted date
    - Clickable items navigate to file in main browser
    - Empty category placeholder messages
    - Progress indicator for large comparisons
    - _Requirements: 3.3, 3.4, 3.7, 3.8, 3.9_

  - [x] 8.4 Create AliasEditSheet view
    - Create `Sources/RetroFilesystemGUI/Views/AliasEditSheet.swift`
    - Small sheet/popover with text field for alias name
    - Save and Cancel buttons
    - Display validation errors inline
    - Remove alias button when alias already exists
    - _Requirements: 4.1, 4.4, 4.8_

  - [x] 8.5 Create MetadataPanel view
    - Create `Sources/RetroFilesystemGUI/Views/MetadataPanel.swift`
    - Side panel (200–400pt width) to left of File_Browser
    - Header showing file name and truncated path (non-editable)
    - TextEditor with monospace font for JSON editing
    - Save button with inline validation errors
    - Undo button (disabled when no prior state)
    - Placeholder when no selection or metadata unavailable
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 6.2, 6.4_

- [x] 9. Wire views into existing app structure
  - [x] 9.1 Integrate new services into ContentView and FileManagerViewModel initialization
    - Update `ContentView.swift` to instantiate `AliasStorageService`, `MetadataStorageService`, `SortingRulesStorageService`
    - Pass new services to `FileManagerViewModel` init
    - Update `FileManagerViewModel` init signature to accept new service dependencies
    - _Requirements: 4.1, 5.1, 6.3, 2.1_

  - [x] 9.2 Integrate SortStatusBadge into FileBrowser view modes
    - Add `SortStatusBadge` overlay to directory items in `IconGridView`, `ListTableView`, and `ColumnBrowserView`
    - Connect badge tap to `toggleUnsortedFilter` on `FileManagerViewModel`
    - _Requirements: 2.1, 2.3, 2.4, 2.7_

  - [x] 9.3 Integrate MetadataPanel into ContentView layout
    - Add `MetadataPanel` to the left of `FileBrowser` in the detail area
    - Toggle visibility via toolbar button or menu item
    - Handle unsaved changes confirmation on selection change
    - _Requirements: 5.1, 5.5, 6.8_

  - [x] 9.4 Integrate AliasEditSheet and alias display into FileBrowser
    - Update `FileBrowser` and sub-views to use `displayName(for:)` for item labels
    - Apply italic styling when `isAliased(_:)` returns true
    - Add context menu item to open `AliasEditSheet`
    - _Requirements: 4.2, 4.3, 4.4_

  - [x] 9.5 Integrate SortingRulesEditor and ComparisonWindow into app
    - Add context menu item on directories to open `SortingRulesEditor` sheet
    - Add menu/toolbar action to open comparison (with 2 directories selected)
    - Present `ComparisonWindow` as a new window
    - Validate selection count before invoking comparison
    - _Requirements: 1.1, 3.5_

  - [ ]* 9.6 Write integration tests for watcher triggering unsorted re-evaluation
    - Verify that file system changes trigger re-evaluation within 5 seconds
    - Test metadata panel update on selection change within 500ms
    - _Requirements: 2.5, 5.3_

- [~] 10. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All new services follow the existing `TagStorageService` pattern (protocol + concrete class, OSLog, atomic writes, custom URL init for testing)
- The Swift `Testing` framework with manual randomized loops is used for property-based tests (matching existing project pattern)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4"] },
    { "id": 1, "tasks": ["2.1", "2.3", "2.5", "2.7"] },
    { "id": 2, "tasks": ["2.2", "2.4", "2.6", "2.8", "4.3", "4.5", "4.7", "4.8"] },
    { "id": 3, "tasks": ["4.1", "4.4", "4.6"] },
    { "id": 4, "tasks": ["4.2"] },
    { "id": 5, "tasks": ["6.1", "6.2", "6.3", "6.5", "6.6"] },
    { "id": 6, "tasks": ["6.4"] },
    { "id": 7, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5"] },
    { "id": 8, "tasks": ["9.1"] },
    { "id": 9, "tasks": ["9.2", "9.3", "9.4", "9.5"] },
    { "id": 10, "tasks": ["9.6"] }
  ]
}
```
