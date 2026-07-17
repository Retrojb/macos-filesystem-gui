# Requirements Document

## Introduction

This document defines requirements for a Finder-like enhanced file manager application for macOS built with SwiftUI. The application provides familiar file browsing capabilities similar to macOS Finder, with enhanced features for file organization, an advanced tagging system for files and videos, and a bulk file renaming tool. The application targets macOS 14+ and is built using Swift Package Manager.

## Glossary

- **File_Manager**: The main application providing file browsing, organization, tagging, and renaming capabilities
- **Navigation_Panel**: The sidebar component displaying favorites, volumes, and folder hierarchy for quick navigation
- **File_Browser**: The main content area displaying files and folders within the current directory
- **Tag_System**: The subsystem responsible for creating, assigning, persisting, and querying tags on files and videos
- **Bulk_Renamer**: The subsystem providing batch file renaming with pattern-based rules
- **File_Item**: A file or folder represented in the file system
- **Tag**: A user-defined label with an optional color that can be assigned to one or more File_Items
- **Rename_Rule**: A pattern or transformation applied during bulk rename operations (e.g., find/replace, sequential numbering, date insertion)
- **Smart_Folder**: A virtual folder that dynamically aggregates File_Items matching specified tag or metadata criteria

## Requirements

### Requirement 1: Directory Browsing and Navigation

**User Story:** As a user, I want to browse my file system in a familiar Finder-like interface, so that I can navigate directories and view files efficiently.

#### Acceptance Criteria

1. WHEN the application launches, THE File_Manager SHALL display the user's home directory contents in the File_Browser, sorted by name in ascending alphabetical order, excluding hidden files and folders by default
2. WHEN a user double-clicks a folder in the File_Browser, THE File_Manager SHALL navigate into that folder and display its contents
3. WHEN a user clicks a location in the Navigation_Panel, THE File_Manager SHALL display the contents of that location in the File_Browser
4. THE Navigation_Panel SHALL display a list of favorites including Desktop, Documents, Downloads, and mounted volumes
5. WHEN a user clicks the back button, THE File_Manager SHALL navigate to the previously viewed directory
6. WHEN a user clicks the forward button after navigating back, THE File_Manager SHALL navigate to the directory that was displayed before back was pressed
7. IF there is no previous directory in the navigation history, THEN THE File_Manager SHALL disable the back button
8. IF there is no forward directory in the navigation history, THEN THE File_Manager SHALL disable the forward button
9. THE File_Browser SHALL display each File_Item with its name (truncated with an ellipsis if exceeding 255 characters), size in human-readable units (bytes, KB, MB, GB), modification date, and kind (derived from the file extension or system-reported uniform type identifier)
10. WHEN a user enters a path in the path bar and presses the Return key, THE File_Manager SHALL navigate to that directory
11. IF a requested directory does not exist or is inaccessible, THEN THE File_Manager SHALL display an error message indicating the reason for the access failure and remain in the current directory
12. IF the current directory is empty, THEN THE File_Browser SHALL display a placeholder message indicating that the folder contains no items

### Requirement 2: File Listing View Modes

**User Story:** As a user, I want to view files in different layouts, so that I can choose the most useful presentation for my current task.

#### Acceptance Criteria

1. THE File_Browser SHALL support an icon grid view displaying File_Items as thumbnails with names
2. THE File_Browser SHALL support a list view displaying File_Items in a sortable table with columns for name, date modified, size, and kind
3. THE File_Browser SHALL support a column view displaying the folder hierarchy in adjacent columns
4. WHEN the application launches for the first time, THE File_Browser SHALL default to the list view mode
5. WHEN a user selects a view mode, THE File_Browser SHALL re-render the current directory contents in the selected layout and persist the choice for subsequent launches
6. WHEN a user clicks a column header in list view, THE File_Browser SHALL sort File_Items by that column in ascending order
7. WHEN a user clicks the same column header a second time in list view, THE File_Browser SHALL reverse the sort order to descending
8. WHEN a user selects a File_Item in column view, THE File_Browser SHALL display the contents of the selected folder in the next column to the right, or display a file preview if the selected item is a file

### Requirement 3: File Operations

**User Story:** As a user, I want to perform common file operations, so that I can manage my files without switching to another application.

#### Acceptance Criteria

1. WHEN a user selects one or more File_Items and presses Delete, THE File_Manager SHALL move the selected items to the Trash
2. WHEN a user drags a File_Item to another folder within the File_Browser, THE File_Manager SHALL move the item to the target folder
3. WHEN a user holds Option and drags a File_Item to another folder, THE File_Manager SHALL copy the item to the target folder
4. WHEN a user presses Command+C followed by Command+V in a different directory, THE File_Manager SHALL copy the selected File_Items to the current directory
5. WHEN a user selects a File_Item and presses Enter, THE File_Manager SHALL make the item name editable for inline renaming, and commit the new name when the user presses Enter again or clicks outside the name field, or cancel the rename when the user presses Escape
6. WHEN a user presses Command+N, THE File_Manager SHALL create a new empty folder in the current directory with the default name "untitled folder" and immediately make the folder name editable for inline renaming
7. IF a file operation fails due to permission or disk space issues, THEN THE File_Manager SHALL display an error alert indicating the failure reason and preserve the original state of all affected File_Items without partial changes
8. IF a move or copy operation targets a folder that already contains a File_Item with the same name, THEN THE File_Manager SHALL prompt the user to choose between replacing the existing item, keeping both items by appending a numeric suffix to the new item name, or cancelling the operation
9. IF a user submits a renamed File_Item name that is empty, exceeds 255 characters, or contains invalid filename characters (colon or slash), THEN THE File_Manager SHALL reject the rename, display an inline error indicating the validation failure, and keep the name field editable with the previous name intact

### Requirement 4: Enhanced File Organization with Smart Folders

**User Story:** As a user, I want to organize files using smart folders based on tags and metadata, so that I can find related files without moving them from their original locations.

#### Acceptance Criteria

1. WHEN a user creates a Smart_Folder, THE File_Manager SHALL prompt for a name (1 to 64 characters) and filter criteria including tags, file type, and date range, where multiple criteria are combined using AND logic
2. THE File_Manager SHALL display Smart_Folders in the Navigation_Panel under a dedicated section
3. WHEN a user opens a Smart_Folder, THE File_Browser SHALL display all File_Items matching the Smart_Folder criteria from all directories accessible within the Navigation_Panel locations
4. WHEN a File_Item is added, removed, or modified in the file system, THE File_Manager SHALL update Smart_Folder contents within 5 seconds
5. THE File_Manager SHALL persist Smart_Folder definitions across application restarts
6. WHEN a user right-clicks a Smart_Folder, THE File_Manager SHALL provide options to edit criteria, rename, or delete the Smart_Folder
7. IF a user attempts to create a Smart_Folder with a name that already exists or with no filter criteria specified, THEN THE File_Manager SHALL display an error message indicating the reason and not create the Smart_Folder
8. WHEN a user opens a Smart_Folder and no File_Items match the filter criteria, THE File_Browser SHALL display an empty state message indicating no matching files were found

### Requirement 5: Tag Management

**User Story:** As a user, I want to create and manage tags, so that I can categorize and retrieve files and videos efficiently.

#### Acceptance Criteria

1. WHEN a user opens the tag management interface, THE Tag_System SHALL display all existing tags with their names and colors, sorted alphabetically by name
2. WHEN a user creates a new tag, THE Tag_System SHALL accept a name (1 to 64 characters) and an optional color selected from a predefined palette of at least 8 colors
3. IF a user attempts to create a tag with a name that matches an existing tag name (case-insensitive comparison), THEN THE Tag_System SHALL display an error indicating the duplicate name
4. WHEN a user edits a tag name or color, THE Tag_System SHALL validate the new name using the same rules as creation (1 to 64 characters, no case-insensitive duplicates) and update the tag across all File_Items that reference the tag
5. WHEN a user deletes a tag, THE Tag_System SHALL display a confirmation prompt indicating how many File_Items reference the tag, and upon confirmation remove the tag association from all File_Items and delete the tag definition
6. THE Tag_System SHALL persist all tag definitions and associations in a local database

### Requirement 6: Tag Assignment and Filtering

**User Story:** As a user, I want to assign tags to files and videos and filter by tags, so that I can quickly locate categorized content.

#### Acceptance Criteria

1. WHEN a user right-clicks one or more File_Items, THE Tag_System SHALL display a context menu option to assign or remove tags, with currently assigned tags indicated by a checkmark
2. WHEN a user assigns a tag to a File_Item, THE Tag_System SHALL store the association and display the tag indicator (colored dot with tag name) on the File_Item in the File_Browser
3. THE File_Manager SHALL support assigning up to 20 tags to a single File_Item
4. IF a user attempts to assign a tag that is already assigned to the selected File_Item, THEN THE Tag_System SHALL ignore the duplicate assignment without displaying an error
5. WHEN a user selects one or more tags from the Navigation_Panel tag filter, THE File_Browser SHALL display only File_Items that have all selected tags assigned
6. IF the tag filter produces no matching File_Items, THEN THE File_Browser SHALL display an empty state message indicating no files match the selected tags
7. WHEN a user drags a File_Item onto a tag in the Navigation_Panel, THE Tag_System SHALL assign that tag to the File_Item and display a brief visual confirmation on the tag
8. THE Tag_System SHALL support tagging video files and display video-specific metadata (duration in HH:MM:SS format, resolution as width×height) alongside tags in the File_Browser

### Requirement 7: Bulk Rename

**User Story:** As a user, I want to rename multiple files at once using patterns, so that I can organize large sets of files efficiently.

#### Acceptance Criteria

1. WHEN a user selects 2 or more File_Items and activates the bulk rename action, THE Bulk_Renamer SHALL display a rename configuration dialog
2. THE Bulk_Renamer SHALL support a find-and-replace Rename_Rule that replaces a text pattern (1 to 255 characters) in file names with a specified replacement (0 to 255 characters)
3. THE Bulk_Renamer SHALL support a sequential numbering Rename_Rule that appends or prepends an incrementing number to each file name, with a user-configurable starting number (default 1) and zero-padding width (1 to 6 digits)
4. THE Bulk_Renamer SHALL support a date insertion Rename_Rule that inserts the file creation or modification date in a user-specified format
5. WHEN a user configures a Rename_Rule, THE Bulk_Renamer SHALL update the preview within 500 milliseconds showing original and resulting names for all selected File_Items, highlighting any resulting names that would conflict with existing files
6. WHEN a user confirms the bulk rename, THE Bulk_Renamer SHALL apply the Rename_Rule to all selected File_Items such that either all renames succeed or no files are renamed
7. IF any file in the batch cannot be renamed due to a name collision with an existing file or a permission error, THEN THE Bulk_Renamer SHALL halt the operation, revert all changes made in that batch, and display an error message indicating which file caused the failure
8. WHEN a user presses Command+Z after a bulk rename, THE Bulk_Renamer SHALL undo the entire batch rename operation, restoring all affected file names to their pre-rename values
9. IF a configured Rename_Rule would produce a resulting file name exceeding 255 characters for any selected File_Item, THEN THE Bulk_Renamer SHALL indicate the violation in the preview and disable the confirm action until the conflict is resolved

### Requirement 8: Tag Persistence and Data Format

**User Story:** As a developer, I want tag data to be stored reliably and parsed correctly, so that tags survive application restarts and data corruption is detected.

#### Acceptance Criteria

1. THE Tag_System SHALL serialize tag definitions and file-tag associations to a JSON-based storage format and write the file to disk whenever a tag is created, edited, deleted, or a tag-file association is modified
2. THE Tag_System SHALL deserialize the JSON storage format back into in-memory tag and association objects, where equivalence is defined as matching tag identifiers, names, colors, and all file-path-to-tag-identifier associations
3. FOR ALL valid tag data objects, serializing then deserializing SHALL produce an equivalent object (round-trip property)
4. IF the stored tag data file is malformed or unreadable, THEN THE Tag_System SHALL log a descriptive error including the file path and parse error message, and initialize with an empty tag set without crashing
5. IF the tag data file does not exist on first launch, THEN THE Tag_System SHALL create a new empty tag data file at the designated storage path
