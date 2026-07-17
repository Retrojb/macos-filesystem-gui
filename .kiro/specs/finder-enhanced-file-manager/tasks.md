 # Implementation Plan: Finder-Enhanced File Manager

## Overview

This plan implements a macOS Finder-like file manager with SwiftUI, structured as incremental coding tasks that build from models and services up through ViewModels to UI components. Each task produces working, testable code that integrates with prior steps.

## Tasks

- [x] 1. Set up project structure, models, and service protocols
  - [x] 1.1 Create directory structure and model files
    - Create `Sources/RetroFilesystemGUI/Models/` directory
    - Create `FileItem.swift` with the `FileItem` struct (Identifiable, Hashable)
    - Create `Tag.swift` with `Tag`, `TagColor`, `TagAssociation`, and `TagStore` structs
    - Create `SmartFolder.swift` with `SmartFolder`, `SmartFolderCriteria` structs
    - Create `RenameRule.swift` with `RenameRule` enum including `Position` and `DateSource`
    - Create `ViewMode.swift` with `ViewMode` enum (Codable)
    - _Requirements: 1.9, 5.2, 4.1, 7.2, 7.3, 7.4, 2.1, 2.2, 2.3_

  - [x] 1.2 Create service protocols
    - Create `Sources/RetroFilesystemGUI/Services/` directory
    - Create `FileSystemServiceProtocol.swift` with `contentsOfDirectory`, `moveItem`, `copyItem`, `trashItem`, `createDirectory`, `renameItem`, `itemExists`
    - Create `TagStorageServiceProtocol.swift` with `load()` and `save(_:)` methods
    - Create `RenameServiceProtocol.swift` with `applyRule`, `execute`, and `revert` methods
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 8.1, 7.6_

  - [x] 1.3 Set up test target in Package.swift
    - Add `testTarget` named `RetroFilesystemGUITests` with dependency on `RetroFilesystemGUI`
    - Create `Tests/RetroFilesystemGUITests/` directory with a placeholder test file
    - _Requirements: 8.3_

- [x] 2. Implement core utility functions and navigation logic
  - [x] 2.1 Implement filename validation utility
    - Create `Sources/RetroFilesystemGUI/Utilities/` directory
    - Create `FilenameValidator.swift` with a function that returns valid if length is 1–255 and does not contain `:` or `/`
    - _Requirements: 3.9_

  - [ ]* 2.2 Write property test for filename validation
    - **Property 3: Filename validation**
    - **Validates: Requirements 3.9**

  - [x] 2.3 Implement file size formatting utility
    - Create `FileSizeFormatter.swift` with a function that converts `Int64` bytes to human-readable string (bytes, KB, MB, GB) with values in [0, 1024) for each unit
    - _Requirements: 1.9_

  - [ ]* 2.4 Write property test for file size formatting
    - **Property 2: File size formatting correctness**
    - **Validates: Requirements 1.9**

  - [x] 2.5 Implement sorting utilities for FileItem
    - Create `FileItemSorting.swift` with sort functions for name, date modified, size, and kind columns
    - Support ascending and descending order
    - _Requirements: 2.6, 2.7_

  - [ ]* 2.6 Write property test for sorting correctness
    - **Property 4: Sorting correctness**
    - **Validates: Requirements 2.6, 2.7**

  - [x] 2.7 Implement navigation history model
    - Create `NavigationState.swift` with `backStack`, `forwardStack`, and navigation methods (`navigateTo`, `goBack`, `goForward`)
    - Back stack max 50 entries; forward stack cleared on new navigation
    - _Requirements: 1.5, 1.6, 1.7, 1.8_

  - [ ]* 2.8 Write property test for navigation history round-trip
    - **Property 1: Navigation history back/forward round-trip**
    - **Validates: Requirements 1.5, 1.6**

- [x] 3. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement tag system services and logic
  - [x] 4.1 Implement TagStorageService
    - Create `TagStorageService.swift` conforming to `TagStorageServiceProtocol`
    - Serialize/deserialize `TagStore` to/from JSON at `~/Library/Application Support/RetroFilesystemGUI/tags.json`
    - Handle malformed JSON by logging error and returning empty TagStore
    - Create empty file on first launch if none exists
    - _Requirements: 8.1, 8.2, 8.4, 8.5_

  - [ ]* 4.2 Write property test for tag store serialization round-trip
    - **Property 15: Tag store serialization round-trip**
    - **Validates: Requirements 8.2, 8.3**

  - [x] 4.3 Implement tag validation and mutation logic
    - Create `TagManager.swift` (or embed in ViewModel) with:
      - `createTag`: validate name 1–64 chars, case-insensitive uniqueness
      - `editTag`: same validation, update associations
      - `deleteTag`: remove tag and all its associations
      - `assignTag`: add association (idempotent)
      - `removeTag`: remove association
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 6.2, 6.4_

  - [ ]* 4.4 Write property test for tag name validation and uniqueness
    - **Property 7: Tag name validation and uniqueness**
    - **Validates: Requirements 5.2, 5.3, 5.4**

  - [ ]* 4.5 Write property test for tag deletion removes all associations
    - **Property 8: Tag deletion removes all associations**
    - **Validates: Requirements 5.5**

  - [ ]* 4.6 Write property test for tag assignment idempotence
    - **Property 9: Tag assignment idempotence and correctness**
    - **Validates: Requirements 6.2, 6.4**

  - [x] 4.7 Implement tag filtering logic
    - Add a function that given a TagStore and selected tag IDs returns file paths whose associated tags are a superset of the selected IDs
    - _Requirements: 6.5_

  - [ ]* 4.8 Write property test for tag filter
    - **Property 10: Tag filter returns files with all selected tags**
    - **Validates: Requirements 6.5**

  - [ ]* 4.9 Write property test for tags alphabetical ordering
    - **Property 17: Tags displayed in alphabetical order**
    - **Validates: Requirements 5.1**

- [x] 5. Implement Smart Folder logic and persistence
  - [x] 5.1 Implement SmartFolder storage and validation
    - Create `SmartFolderStorageService.swift` to persist smart folders as JSON at `~/Library/Application Support/RetroFilesystemGUI/smart_folders.json`
    - Implement creation validation: name 1–64 chars, no duplicate names (case-insensitive), at least one criterion
    - _Requirements: 4.1, 4.5, 4.7_

  - [ ]* 5.2 Write property test for smart folder creation validation
    - **Property 6: Smart folder creation validation**
    - **Validates: Requirements 4.7**

  - [x] 5.3 Implement SmartFolder filter logic
    - Create a filter function that takes FileItems with their tags and a SmartFolderCriteria, returns items matching ALL criteria (required tags AND file type AND date range)
    - _Requirements: 4.3_

  - [ ]* 5.4 Write property test for smart folder filter AND logic
    - **Property 5: Smart folder filter AND logic**
    - **Validates: Requirements 4.3**

  - [ ]* 5.5 Write property test for smart folder persistence round-trip
    - **Property 16: Smart folder persistence round-trip**
    - **Validates: Requirements 4.5**

- [x] 6. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement bulk rename service
  - [x] 7.1 Implement RenameService
    - Create `RenameService.swift` conforming to `RenameServiceProtocol`
    - Implement `applyRule` for find-and-replace: use `String.replacingOccurrences(of:with:)`
    - Implement `applyRule` for sequential numbering: prepend/append zero-padded numbers starting from configured start
    - Implement `applyRule` for date insertion: insert formatted creation/modification date
    - Implement `execute` with atomic semantics: validate all targets first, fail and revert if any rename fails
    - Implement `revert`: restore files from destination back to source in reverse order
    - _Requirements: 7.2, 7.3, 7.4, 7.6, 7.7, 7.8_

  - [x] 7.2 Write property test for find-and-replace rename rule
    - **Property 11: Find-and-replace rename rule**
    - **Validates: Requirements 7.2**

  - [x] 7.3 Write property test for sequential numbering rename rule
    - **Property 12: Sequential numbering rename rule**
    - **Validates: Requirements 7.3**

  - [ ]* 7.4 Write property test for bulk rename atomicity and undo
    - **Property 13: Bulk rename atomicity and undo round-trip**
    - **Validates: Requirements 7.6, 7.8**

  - [ ]* 7.5 Write property test for bulk rename preview length validation
    - **Property 14: Bulk rename preview length validation**
    - **Validates: Requirements 7.9**

- [x] 8. Implement FileSystemService
  - [x] 8.1 Implement FileSystemService
    - Create `FileSystemService.swift` conforming to `FileSystemServiceProtocol`
    - Use `FileManager` for directory contents, move, copy, trash, create directory, rename
    - Map file metadata (size, dates, UTI kind, hidden flag) to `FileItem`
    - Handle permission errors, disk space errors, and name collisions
    - _Requirements: 1.1, 1.2, 1.11, 3.1, 3.2, 3.3, 3.4, 3.6, 3.7, 3.8_

- [x] 9. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement ViewModels
  - [x] 10.1 Implement FileManagerViewModel
    - Create `Sources/RetroFilesystemGUI/ViewModels/` directory
    - Create `FileManagerViewModel.swift` as `@Observable` class
    - Wire FileSystemService and TagStorageService
    - Implement: `navigateTo`, `goBack`, `goForward`, `deleteSelected`, `moveItems`, `copyItems`, `createNewFolder`, `renameItem`
    - Load home directory on init, default to list view sorted by name ascending
    - Persist view mode and sort preferences via UserDefaults
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 1.8, 1.10, 1.11, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

  - [x] 10.2 Implement TagManagerViewModel
    - Create `TagManagerViewModel.swift` as `@Observable` class
    - Wire TagStorageService
    - Implement: `createTag`, `editTag`, `deleteTag`, `assignTag`, `removeTag`, `tagsForFile`, `filesMatchingTags`
    - Tags sorted alphabetically for display
    - Support max 20 tags per file
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 10.3 Implement BulkRenameViewModel
    - Create `BulkRenameViewModel.swift` as `@Observable` class
    - Wire RenameService
    - Implement: `updatePreview` (within 500ms debounce), `confirm`, `undo`
    - Set `canConfirm` to false if any result exceeds 255 chars or has conflicts
    - Store last `RenameTransaction` for undo
    - _Requirements: 7.1, 7.5, 7.6, 7.7, 7.8, 7.9_

- [x] 11. Implement UI components — Navigation and layout
  - [x] 11.1 Implement ContentView with NavigationSplitView layout
    - Refactor `ContentView.swift` to use `NavigationSplitView` with sidebar and detail
    - Add toolbar with back/forward buttons, view mode picker
    - Instantiate FileManagerViewModel and TagManagerViewModel as environment state
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 11.2 Implement NavigationPanel (sidebar)
    - Create `Sources/RetroFilesystemGUI/Views/NavigationPanel.swift`
    - Display Favorites section: Desktop, Documents, Downloads, mounted volumes
    - Display Smart Folders section with right-click context menu (edit, rename, delete)
    - Display Tags filter section with selectable tag list
    - Support drag-and-drop of files onto tags
    - _Requirements: 1.3, 1.4, 4.2, 4.6, 6.5, 6.7_

  - [x] 11.3 Implement PathBar
    - Create `Sources/RetroFilesystemGUI/Views/PathBar.swift`
    - Display breadcrumb path components as clickable buttons
    - Provide editable text field mode on click; navigate on Return
    - _Requirements: 1.10_

- [x] 12. Implement UI components — File Browser views
  - [x] 12.1 Implement FileBrowser container
    - Create `Sources/RetroFilesystemGUI/Views/FileBrowser.swift`
    - Switch between IconGridView, ListTableView, ColumnBrowserView based on viewMode
    - Display empty state placeholder when directory is empty or filter has no results
    - _Requirements: 2.1, 2.2, 2.3, 1.12, 4.8, 6.6_

  - [x] 12.2 Implement IconGridView
    - Create `Sources/RetroFilesystemGUI/Views/IconGridView.swift`
    - Use `LazyVGrid` to display file thumbnails with names
    - Support selection and double-click to navigate into folders
    - _Requirements: 2.1, 1.2_

  - [x] 12.3 Implement ListTableView
    - Create `Sources/RetroFilesystemGUI/Views/ListTableView.swift`
    - Use `Table` with sortable columns: name, date modified, size, kind
    - Display tag indicators (colored dots) on tagged items
    - Show video metadata (duration, resolution) for video files
    - _Requirements: 2.2, 2.6, 2.7, 6.2, 6.8_

  - [x] 12.4 Implement ColumnBrowserView
    - Create `Sources/RetroFilesystemGUI/Views/ColumnBrowserView.swift`
    - Use horizontal `ScrollView` with directory columns
    - Selecting a folder shows its contents in the next column; selecting a file shows a preview
    - _Requirements: 2.3, 2.8_

- [x] 13. Implement UI components — File operations and context menus
  - [x] 13.1 Implement file operation keyboard shortcuts and drag-and-drop
    - Add keyboard handlers for Delete (trash), Cmd+C/Cmd+V (copy-paste), Cmd+N (new folder), Enter (inline rename), Escape (cancel rename)
    - Implement drag-and-drop for move (default) and copy (Option+drag)
    - Show name collision dialog (replace, keep both, cancel)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.8_

  - [x] 13.2 Implement tag context menu and assignment UI
    - Add right-click context menu on File_Items with tag assign/remove submenu
    - Display checkmarks for already-assigned tags
    - Show brief visual confirmation when tag is assigned via drag
    - _Requirements: 6.1, 6.3, 6.7_

- [x] 14. Implement UI components — Dialogs and sheets
  - [x] 14.1 Implement TagManagementView
    - Create `Sources/RetroFilesystemGUI/Views/TagManagementView.swift`
    - Display all tags sorted alphabetically with color swatches
    - Support create, edit (name + color), and delete with confirmation (showing affected file count)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 14.2 Implement BulkRenameDialog
    - Create `Sources/RetroFilesystemGUI/Views/BulkRenameDialog.swift`
    - Rule configuration: find-and-replace, sequential numbering (start, padding), date insertion (source, format)
    - Live preview table showing original → result names
    - Highlight conflicts and length violations
    - Disable confirm when invalid; support Cmd+Z undo
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.9_

  - [x] 14.3 Implement SmartFolderEditor
    - Create `Sources/RetroFilesystemGUI/Views/SmartFolderEditor.swift`
    - Form for name, tag selection, file type, date range
    - Validate name (1–64 chars, unique) and require at least one criterion
    - _Requirements: 4.1, 4.7_

- [x] 15. Integration wiring and final polish
  - [x] 15.1 Wire ViewModels to Views and integrate Smart Folder monitoring
    - Connect FileManagerViewModel state changes to FileBrowser refresh
    - Implement file system watcher (using `DispatchSource` or polling) for Smart Folder updates within 5 seconds
    - Wire tag filtering from NavigationPanel to FileBrowser
    - Ensure error alerts display from ViewModel `errorMessage` properties
    - _Requirements: 4.4, 1.11, 3.7_

  - [x] 15.2 Write integration tests for file operations
    - Test move, copy, delete, rename with real temporary directories
    - Test error cases (permissions, name collisions)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7, 3.8_

  - [x] 15.3 Write integration tests for tag persistence
    - Test read/write with real file I/O
    - Test malformed JSON recovery
    - Test first-launch file creation
    - _Requirements: 8.1, 8.2, 8.4, 8.5_

- [x] 16. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- All service protocols enable mock injection for isolated testing
- The implementation uses macOS 14 `@Observable` (Observation framework) instead of `ObservableObject`/`@Published`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "2.3", "2.5", "2.7"] },
    { "id": 2, "tasks": ["2.2", "2.4", "2.6", "2.8"] },
    { "id": 3, "tasks": ["4.1", "4.3", "4.7"] },
    { "id": 4, "tasks": ["4.2", "4.4", "4.5", "4.6", "4.8", "4.9"] },
    { "id": 5, "tasks": ["5.1", "5.3"] },
    { "id": 6, "tasks": ["5.2", "5.4", "5.5"] },
    { "id": 7, "tasks": ["7.1", "8.1"] },
    { "id": 8, "tasks": ["7.2", "7.3", "7.4", "7.5"] },
    { "id": 9, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 10, "tasks": ["11.1"] },
    { "id": 11, "tasks": ["11.2", "11.3", "12.1"] },
    { "id": 12, "tasks": ["12.2", "12.3", "12.4"] },
    { "id": 13, "tasks": ["13.1", "13.2"] },
    { "id": 14, "tasks": ["14.1", "14.2", "14.3"] },
    { "id": 15, "tasks": ["15.1"] },
    { "id": 16, "tasks": ["15.2", "15.3"] }
  ]
}
```
