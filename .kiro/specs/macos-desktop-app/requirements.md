# Requirements Document

## Introduction

A simple macOS desktop application scaffold for local development and personal use. The application provides a native macOS window with standard application lifecycle management. It is not intended for distribution via the App Store or otherwise — it runs locally on the developer's machine during development.

## Glossary

- **App**: The macOS desktop application being built
- **Main_Window**: The primary application window displayed to the user
- **App_Delegate**: The component responsible for managing application lifecycle events
- **Menu_Bar**: The macOS menu bar containing application menus
- **Build_System**: The tooling used to compile and run the application locally

## Requirements

### Requirement 1: Application Launches with a Main Window

**User Story:** As a developer, I want the app to launch and display a window, so that I have a visible canvas to build upon.

#### Acceptance Criteria

1. WHEN the App is launched, THE Main_Window SHALL appear on screen with a default size of at least 800x600 points
2. THE Main_Window SHALL display the application name as the title in the title bar
3. WHEN the App is launched, THE Main_Window SHALL be centered on the primary screen
4. THE Main_Window SHALL be resizable, closable, and miniaturizable

### Requirement 2: Standard macOS Application Lifecycle

**User Story:** As a developer, I want the app to follow standard macOS lifecycle conventions, so that it behaves like a native application.

#### Acceptance Criteria

1. WHEN the user closes the Main_Window, THE App SHALL terminate the process so that no application process remains running
2. WHEN the App is launched, THE App_Delegate SHALL set the application activation policy and register lifecycle handlers before the Main_Window is displayed
3. WHEN the App receives a terminate request, THE App SHALL exit within 5 seconds with a zero exit code and no crash log generated
4. IF the App fails to terminate within 5 seconds of receiving a terminate request, THEN THE App SHALL force-terminate the process

### Requirement 3: Native macOS Menu Bar

**User Story:** As a developer, I want a standard menu bar, so that the app feels native and I can extend it later.

#### Acceptance Criteria

1. WHEN the App is launched, THE Menu_Bar SHALL display an application menu titled with the App's configured product name
2. THE Menu_Bar SHALL include a Quit menu item with the keyboard shortcut Cmd+Q that terminates the App
3. THE Menu_Bar SHALL include an Edit menu with Cut (Cmd+X), Copy (Cmd+C), and Paste (Cmd+V) items that perform the corresponding system clipboard operations

### Requirement 4: Local Build and Run

**User Story:** As a developer, I want to build and run the app locally with a single command, so that I can iterate quickly.

#### Acceptance Criteria

1. WHEN the developer runs `swift build` from the project root directory, THE Build_System SHALL compile the application and exit with a zero exit code
2. WHEN the developer runs `swift run` from the project root directory, THE Build_System SHALL launch the compiled App and the Main_Window SHALL appear on screen within 10 seconds
3. THE Build_System SHALL use Swift and SwiftUI as the application framework and SHALL require Swift 5.9 or later
4. THE Build_System SHALL support building via either Xcode or the Swift command-line tools using the same Package.swift manifest
5. IF the build command encounters a compilation error, THEN THE Build_System SHALL exit with a non-zero exit code and output a message indicating the failure cause

### Requirement 5: Project Structure

**User Story:** As a developer, I want a clean project structure, so that I can navigate and extend the codebase easily.

#### Acceptance Criteria

1. THE App SHALL organize source files into a Sources/<TargetName>/ directory following the Swift Package Manager convention
2. THE App SHALL place the application entry point in a separate file from view definitions, with at least one dedicated file for the main app entry and at least one dedicated file for view components
3. THE App SHALL include a Package.swift file that declares an executable target, specifies macOS as the supported platform with a minimum deployment version, and lists any required dependencies
4. THE App SHALL contain no more than one level of subdirectories within Sources/<TargetName>/ at initial scaffold
