# Requirements Document

## Introduction

This document defines requirements for four new capabilities in the RetroFilesystemGUI macOS file manager application: unsorted files detection, directory comparison, file alias names, and a JSON metadata panel. These features enhance file organization, comparison, display customization, and metadata inspection within the existing SwiftUI NavigationSplitView architecture.

## Glossary

- **File_Manager**: The RetroFilesystemGUI macOS application that provides file browsing, navigation, and management capabilities.
- **File_Browser**: The detail panel component that displays file items in icon grid, list, or column view modes.
- **Sorting_Rule**: A user-defined rule that specifies which file types, name patterns, or tags belong in a given directory.
- **Unsorted_File**: A file within a directory that does not match any active Sorting_Rule for that directory.
- **Sort_Status_Indicator**: A visual badge displayed on directories in the File_Browser indicating the presence of Unsorted_Files.
- **Directory_Comparator**: The component responsible for analyzing and presenting differences between two directories.
- **Comparison_Result**: The output of a directory comparison containing files unique to each directory and files common to both.
- **Comparison_Window**: A popup window that displays the Comparison_Result to the user.
- **Alias_Name**: A user-defined display name assigned to a file or folder that appears in the GUI instead of the filesystem name.
- **Alias_Store**: A JSON persistence file at ~/Library/Application Support/RetroFilesystemGUI/aliases.json that maps file paths to their Alias_Names.
- **Metadata_Panel**: A side panel displayed to the left of the File_Browser that shows and allows editing of JSON metadata for a selected file or folder.
- **File_Metadata**: A JSON document containing extended attributes and user-defined properties stored per-file in the application's metadata store.
- **Metadata_Store**: A JSON persistence file at ~/Library/Application Support/RetroFilesystemGUI/metadata.json that contains File_Metadata for all annotated items.
- **Navigation_Panel**: The existing sidebar component displaying Favorites, Smart Folders, and Tags.

## Requirements

### Requirement 1: Define Sorting Rules for Directories

**User Story:** As a user, I want to define sorting rules for specific directories, so that the system can identify which files are unsorted.

#### Acceptance Criteria

1. WHEN the user opens the sorting rules editor for a directory, THE File_Manager SHALL display a form allowing creation of Sorting_Rules with a rule type of file extension (without leading dot, 1–20 characters), name pattern (glob syntax, 1–255 characters), or assigned tag (selected from existing tags).
2. WHEN the user saves a Sorting_Rule with a non-empty and valid pattern, THE File_Manager SHALL persist the rule in ~/Library/Application Support/RetroFilesystemGUI/sorting-rules.json associated with the directory path.
3. THE File_Manager SHALL support a maximum of 50 Sorting_Rules per directory, treating a file as sorted if it matches at least one rule.
4. WHEN a Sorting_Rule is deleted, THE File_Manager SHALL remove the rule from persistence and re-evaluate unsorted status for the affected directory within 3 seconds.
5. IF the sorting rules file is missing or contains malformed JSON, THEN THE File_Manager SHALL create a new empty rules file and log a warning.
6. IF the user attempts to save a Sorting_Rule with an empty pattern or a pattern exceeding the maximum length, THEN THE File_Manager SHALL display an inline validation error indicating the constraint and retain the user's input in the form.
7. IF writing to the sorting rules file fails, THEN THE File_Manager SHALL display an error message indicating the save failed and preserve the existing rules file unchanged.

### Requirement 2: Detect and Display Unsorted Files

**User Story:** As a user, I want to see which directories contain unsorted files, so that I can quickly identify areas needing organization.

#### Acceptance Criteria

1. WHEN a directory contains one or more Unsorted_Files, THE Sort_Status_Indicator SHALL display a numeric badge showing the count of unsorted files on that directory in the File_Browser, capped at "99+" for counts exceeding 99.
2. WHILE a directory has no Sorting_Rules defined, THE File_Manager SHALL treat all files in that directory as sorted and display no Sort_Status_Indicator.
3. WHEN the user clicks the Sort_Status_Indicator, THE File_Manager SHALL filter the File_Browser to show only Unsorted_Files in that directory.
4. WHEN the user clicks the Sort_Status_Indicator a second time while the filter is active, THE File_Manager SHALL clear the unsorted filter and display all files in the directory.
5. WHEN the file system watcher detects a change in a directory with active Sorting_Rules, THE File_Manager SHALL re-evaluate unsorted file status within 5 seconds of the change.
6. THE File_Manager SHALL evaluate unsorted status by comparing each file against all Sorting_Rules for its parent directory and marking the file as unsorted if it matches no rule.
7. THE Sort_Status_Indicator SHALL be displayed consistently across all three File_Browser view modes (icon grid, list, column).

### Requirement 3: Compare Two Directories

**User Story:** As a user, I want to compare the contents of two directories side by side, so that I can identify differences and duplicates.

#### Acceptance Criteria

1. WHEN the user selects exactly two directories and invokes the compare action, THE Directory_Comparator SHALL produce a Comparison_Result containing three categories: files unique to the first directory, files unique to the second directory, and files present in both directories, based on the immediate (non-recursive) children of each directory.
2. THE Directory_Comparator SHALL determine file sameness by comparing file names using a case-sensitive string match, including both files and subdirectories in the comparison.
3. WHEN a Comparison_Result is produced, THE File_Manager SHALL display a Comparison_Window showing all three categories, each in its own labeled section separated by visible section headers indicating "Only in [directory name]" and "In Both".
4. THE Comparison_Window SHALL display the file name, size (formatted in human-readable units: bytes, KB, MB, GB), and modification date (formatted using the user's system locale settings) for each item in the result.
5. WHEN the user selects fewer or more than two directories and invokes the compare action, THE File_Manager SHALL display an error message stating that exactly two directories must be selected.
6. IF either selected directory is inaccessible due to permissions, THEN THE File_Manager SHALL display an error message identifying which directory cannot be read by its name and shall not produce a partial Comparison_Result.
7. WHEN the user clicks a file in the Comparison_Window, THE File_Manager SHALL navigate to that file's parent directory and select the file in the main browser view.
8. IF both directories are accessible but one or both contain no items, THEN THE Directory_Comparator SHALL produce a valid Comparison_Result with the appropriate categories empty, and THE Comparison_Window SHALL display a placeholder message in each empty category indicating no files were found.
9. WHILE a directory comparison is in progress for directories containing more than 10,000 immediate children combined, THE File_Manager SHALL display a progress indicator in the Comparison_Window until the Comparison_Result is ready.

### Requirement 4: Assign Alias Names to Files and Folders

**User Story:** As a user, I want to assign custom display names to files and folders, so that I can see friendly names in the GUI without renaming files on disk.

#### Acceptance Criteria

1. WHEN the user assigns an Alias_Name to a file or folder, THE File_Manager SHALL persist the mapping (file path to Alias_Name) in the Alias_Store, where the Alias_Name is a non-empty string of 1 to 255 characters that does not contain the characters '/' or ':'.
2. WHILE a file or folder has an Alias_Name assigned, THE File_Browser SHALL display the Alias_Name instead of the filesystem name in all view modes (icon grid, list, column).
3. WHILE a file or folder has an Alias_Name assigned, THE File_Browser SHALL render the item name in italic style to distinguish aliased items from non-aliased items.
4. WHEN the user removes an Alias_Name from a file or folder, THE File_Browser SHALL revert to displaying the original filesystem name and remove the italic style.
5. THE File_Manager SHALL preserve the original filesystem name unchanged when an Alias_Name is assigned or modified.
6. WHEN the File_Manager refreshes a directory listing, IF a persisted alias path no longer exists on disk, THEN THE File_Manager SHALL remove the stale alias mapping from the Alias_Store.
7. IF the Alias_Store file is missing or contains malformed JSON, THEN THE File_Manager SHALL create a new empty alias file and log a warning.
8. IF the user submits an Alias_Name that is empty, exceeds 255 characters, or contains '/' or ':', THEN THE File_Manager SHALL reject the input and display an error message indicating the validation failure.
9. WHEN the Alias_Store is loaded successfully, THE File_Manager SHALL produce an equivalent data structure when the JSON content is parsed, serialized, and parsed again (round-trip integrity).

### Requirement 5: Display JSON Metadata Panel

**User Story:** As a user, I want to view a file or folder's JSON metadata in a side panel, so that I can inspect extended properties at a glance.

#### Acceptance Criteria

1. WHEN the user activates the Metadata_Panel and a file or folder is selected, THE Metadata_Panel SHALL display the File_Metadata for that item as pretty-printed JSON with 2-space indentation in a panel to the left of the File_Browser, where the panel width is between 200 and 400 points inclusive.
2. WHILE the Metadata_Panel is visible and no item is selected, THE Metadata_Panel SHALL display a placeholder message indicating no selection.
3. WHEN the user selects a different file or folder while the Metadata_Panel is visible, THE Metadata_Panel SHALL update to display the newly selected item's File_Metadata within 500 milliseconds.
4. WHEN a selected item has no existing File_Metadata in the Metadata_Store, THE Metadata_Panel SHALL display an empty JSON object ({}) in the JSON content area.
5. WHEN the Metadata_Panel is toggled off, THE File_Manager SHALL hide the panel and restore the File_Browser to its full width.
6. WHILE the Metadata_Panel is visible and an item is selected, THE Metadata_Panel SHALL display the item's filesystem name and absolute path as a non-editable header above the JSON content, truncating the path with a leading ellipsis if it exceeds 80 characters.
7. IF the Metadata_Store cannot be read when the Metadata_Panel is activated, THEN THE Metadata_Panel SHALL display a message indicating that metadata is unavailable and treat all items as having no existing File_Metadata.

### Requirement 6: Edit JSON Metadata

**User Story:** As a user, I want to edit file or folder JSON metadata directly in the side panel, so that I can annotate items with custom properties.

#### Acceptance Criteria

1. WHEN the user edits JSON content in the Metadata_Panel and clicks save, THE File_Manager SHALL validate the content as well-formed JSON and is no larger than 1 MB before persisting.
2. IF the user enters malformed JSON and clicks save, THEN THE File_Manager SHALL display an inline error message indicating the line number and character position of the first parse error, and refuse to persist the change.
3. WHEN valid JSON metadata is saved, THE File_Manager SHALL persist the updated File_Metadata to the Metadata_Store associated with the item's file path.
4. WHEN the user invokes undo (Cmd+Z) after a metadata save, THE File_Manager SHALL revert the File_Metadata to the previous saved state (single-level undo). IF no prior saved state exists, THEN THE File_Manager SHALL disable the undo action.
5. IF the Metadata_Store file is missing or contains malformed JSON, THEN THE File_Manager SHALL create a new empty metadata file and log a warning.
6. FOR ALL valid Metadata_Store JSON documents, parsing then serializing then parsing the Metadata_Store SHALL produce an equivalent data structure (round-trip property).
7. WHEN a file is moved or deleted from disk, THE File_Manager SHALL remove the associated File_Metadata entry from the Metadata_Store during the next directory refresh.
8. IF the user selects a different item while the Metadata_Panel contains unsaved edits, THEN THE File_Manager SHALL display a confirmation prompt offering to save or discard the pending changes before switching to the newly selected item's metadata.
9. IF the user attempts to save JSON content larger than 1 MB, THEN THE File_Manager SHALL display an inline error message indicating the size limit and refuse to persist the change.

### Requirement 7: Parse and Print Metadata Store

**User Story:** As a developer, I want reliable serialization of the metadata and alias stores, so that data integrity is maintained across sessions.

#### Acceptance Criteria

1. THE File_Manager SHALL serialize the Metadata_Store using JSONEncoder with prettyPrinted and sortedKeys formatting options, writing the data atomically to the storage file.
2. THE File_Manager SHALL serialize the Alias_Store using JSONEncoder with prettyPrinted and sortedKeys formatting options, writing the data atomically to the storage file.
3. WHEN the File_Manager loads the Metadata_Store and the storage file exists and contains valid JSON, THE parser SHALL decode the JSON into a structured MetadataStore model containing a dictionary of file path strings to arbitrary JSON metadata values.
4. WHEN the File_Manager loads the Alias_Store and the storage file exists and contains valid JSON, THE parser SHALL decode the JSON into a structured AliasStore model containing a dictionary of file path strings to Alias_Name strings.
5. IF the storage file does not exist when the File_Manager loads the Metadata_Store or Alias_Store, THEN THE File_Manager SHALL create a new file containing an empty store and return that empty store.
6. IF the storage file contains malformed or non-decodable JSON when the File_Manager loads the Metadata_Store or Alias_Store, THEN THE File_Manager SHALL log a descriptive error and return an empty store.
7. FOR ALL valid MetadataStore instances, encoding then decoding SHALL produce a MetadataStore that is equal to the original as determined by Swift Equatable conformance (round-trip property).
8. FOR ALL valid AliasStore instances, encoding then decoding SHALL produce an AliasStore that is equal to the original as determined by Swift Equatable conformance (round-trip property).
