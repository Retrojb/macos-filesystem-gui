import SwiftUI

@main
struct RetroFilesystemGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            // SwiftUI provides the application menu (with Quit/Cmd+Q) and
            // Edit menu (Cut/Copy/Paste) by default. Add custom CommandGroup
            // or CommandMenu entries here for future extensibility.
        }
    }
}
