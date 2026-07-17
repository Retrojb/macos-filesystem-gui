import Testing
import Foundation
@testable import RetroFilesystemGUI

@Suite("NavigationState Tests")
struct NavigationStateTests {

    private let homeDir = URL(fileURLWithPath: "/Users/test/home")
    private let documentsDir = URL(fileURLWithPath: "/Users/test/Documents")
    private let downloadsDir = URL(fileURLWithPath: "/Users/test/Downloads")
    private let desktopDir = URL(fileURLWithPath: "/Users/test/Desktop")

    @Test("Initial state has empty stacks")
    func initialState() {
        let state = NavigationState(currentDirectory: homeDir)
        #expect(state.currentDirectory == homeDir)
        #expect(state.canGoBack == false)
        #expect(state.canGoForward == false)
    }

    @Test("navigateTo pushes current to back stack and clears forward stack")
    func navigateTo() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)

        #expect(state.currentDirectory == documentsDir)
        #expect(state.canGoBack == true)
        #expect(state.canGoForward == false)
    }

    @Test("goBack pops from back stack and pushes current to forward stack")
    func goBack() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)
        state.goBack()

        #expect(state.currentDirectory == homeDir)
        #expect(state.canGoBack == false)
        #expect(state.canGoForward == true)
    }

    @Test("goForward pops from forward stack and pushes current to back stack")
    func goForward() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)
        state.goBack()
        state.goForward()

        #expect(state.currentDirectory == documentsDir)
        #expect(state.canGoBack == true)
        #expect(state.canGoForward == false)
    }

    @Test("goBack then goForward returns to original directory (round-trip)")
    func roundTrip() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)
        state.navigateTo(downloadsDir)

        let beforeBack = state.currentDirectory
        state.goBack()
        state.goForward()

        #expect(state.currentDirectory == beforeBack)
    }

    @Test("navigateTo clears forward stack")
    func navigateToClearsForwardStack() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)
        state.goBack()
        #expect(state.canGoForward == true)

        state.navigateTo(downloadsDir)
        #expect(state.canGoForward == false)
    }

    @Test("goBack on empty back stack is a no-op")
    func goBackOnEmptyStack() {
        var state = NavigationState(currentDirectory: homeDir)
        state.goBack()
        #expect(state.currentDirectory == homeDir)
    }

    @Test("goForward on empty forward stack is a no-op")
    func goForwardOnEmptyStack() {
        var state = NavigationState(currentDirectory: homeDir)
        state.goForward()
        #expect(state.currentDirectory == homeDir)
    }

    @Test("Back stack respects max 50 entries")
    func backStackMaxSize() {
        var state = NavigationState(currentDirectory: homeDir)

        for i in 1...60 {
            state.navigateTo(URL(fileURLWithPath: "/dir/\(i)"))
        }

        #expect(state.backStack.count == 50)
        // The oldest entry should have been dropped
        #expect(state.backStack.first != homeDir)
    }

    @Test("Multiple back and forward navigations maintain correct state")
    func multipleNavigations() {
        var state = NavigationState(currentDirectory: homeDir)
        state.navigateTo(documentsDir)
        state.navigateTo(downloadsDir)
        state.navigateTo(desktopDir)

        state.goBack() // -> Downloads
        #expect(state.currentDirectory == downloadsDir)

        state.goBack() // -> Documents
        #expect(state.currentDirectory == documentsDir)

        state.goForward() // -> Downloads
        #expect(state.currentDirectory == downloadsDir)

        state.goForward() // -> Desktop
        #expect(state.currentDirectory == desktopDir)

        #expect(state.canGoForward == false)
    }
}
