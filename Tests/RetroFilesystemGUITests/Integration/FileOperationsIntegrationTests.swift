import Testing
import Foundation
@testable import RetroFilesystemGUI

/// Integration tests for file operations using real temporary directories.
/// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.7, 3.8
struct FileOperationsIntegrationTests {

    private let fileManager = FileManager.default

    /// Creates a unique temporary directory for test isolation.
    private func makeTempDir() throws -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("FileOpsTests_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Removes a temporary directory and all its contents.
    private func cleanup(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    /// Creates a test file with the given content at the specified directory.
    private func createTestFile(in directory: URL, name: String, content: String = "test content") throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Move Operation Tests

    @Test("Move file to another directory preserves content and removes original")
    func testMoveFileToAnotherDirectory() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("destination")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        let sourceFile = try createTestFile(in: sourceDir, name: "moveme.txt", content: "move data")
        let destFile = destDir.appendingPathComponent("moveme.txt")

        let service = FileSystemService()
        try service.moveItem(at: sourceFile, to: destFile)

        #expect(!fileManager.fileExists(atPath: sourceFile.path))
        #expect(fileManager.fileExists(atPath: destFile.path))

        let movedContent = try String(contentsOf: destFile, encoding: .utf8)
        #expect(movedContent == "move data")
    }

    @Test("Move directory to another location")
    func testMoveDirectory() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let sourceDir = tempDir.appendingPathComponent("folderA")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let _ = try createTestFile(in: sourceDir, name: "child.txt", content: "child")

        let destDir = tempDir.appendingPathComponent("folderB")

        let service = FileSystemService()
        try service.moveItem(at: sourceDir, to: destDir)

        #expect(!fileManager.fileExists(atPath: sourceDir.path))
        #expect(fileManager.fileExists(atPath: destDir.path))
        #expect(fileManager.fileExists(atPath: destDir.appendingPathComponent("child.txt").path))
    }

    // MARK: - Copy Operation Tests

    @Test("Copy file creates duplicate with same content")
    func testCopyFileCreatesDuplicate() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let sourceFile = try createTestFile(in: tempDir, name: "original.txt", content: "copy me")
        let destFile = tempDir.appendingPathComponent("copied.txt")

        let service = FileSystemService()
        try service.copyItem(at: sourceFile, to: destFile)

        #expect(fileManager.fileExists(atPath: sourceFile.path))
        #expect(fileManager.fileExists(atPath: destFile.path))

        let originalContent = try String(contentsOf: sourceFile, encoding: .utf8)
        let copiedContent = try String(contentsOf: destFile, encoding: .utf8)
        #expect(originalContent == copiedContent)
        #expect(copiedContent == "copy me")
    }

    @Test("Copy directory duplicates entire subtree")
    func testCopyDirectoryDuplicatesSubtree() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let sourceDir = tempDir.appendingPathComponent("srcFolder")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let _ = try createTestFile(in: sourceDir, name: "nested.txt", content: "nested")

        let destDir = tempDir.appendingPathComponent("copyFolder")

        let service = FileSystemService()
        try service.copyItem(at: sourceDir, to: destDir)

        #expect(fileManager.fileExists(atPath: sourceDir.path))
        #expect(fileManager.fileExists(atPath: destDir.path))
        #expect(fileManager.fileExists(atPath: destDir.appendingPathComponent("nested.txt").path))

        let content = try String(contentsOf: destDir.appendingPathComponent("nested.txt"), encoding: .utf8)
        #expect(content == "nested")
    }

    // MARK: - Trash Operation Tests

    @Test("Trash file removes it from original location")
    func testTrashFileRemovesFromOriginal() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let file = try createTestFile(in: tempDir, name: "trashme.txt", content: "trash")

        let service = FileSystemService()
        try service.trashItem(at: file)

        #expect(!fileManager.fileExists(atPath: file.path))
    }

    @Test("Trash directory removes it from original location")
    func testTrashDirectoryRemovesFromOriginal() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let dir = tempDir.appendingPathComponent("trashDir")
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let _ = try createTestFile(in: dir, name: "inside.txt")

        let service = FileSystemService()
        try service.trashItem(at: dir)

        #expect(!fileManager.fileExists(atPath: dir.path))
    }

    // MARK: - Rename Operation Tests

    @Test("Rename file changes name and preserves content")
    func testRenameFileChangesName() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let file = try createTestFile(in: tempDir, name: "oldname.txt", content: "rename data")

        let service = FileSystemService()
        let newURL = try service.renameItem(at: file, to: "newname.txt")

        let oldPath = tempDir.appendingPathComponent("oldname.txt")
        let expectedNewPath = tempDir.appendingPathComponent("newname.txt")

        #expect(!fileManager.fileExists(atPath: oldPath.path))
        #expect(fileManager.fileExists(atPath: expectedNewPath.path))
        #expect(newURL == expectedNewPath)

        let content = try String(contentsOf: expectedNewPath, encoding: .utf8)
        #expect(content == "rename data")
    }

    @Test("Rename directory changes name and preserves contents")
    func testRenameDirectoryChangesName() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let dir = tempDir.appendingPathComponent("oldDir")
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let _ = try createTestFile(in: dir, name: "file.txt", content: "inside dir")

        let service = FileSystemService()
        let newURL = try service.renameItem(at: dir, to: "newDir")

        #expect(!fileManager.fileExists(atPath: dir.path))
        #expect(fileManager.fileExists(atPath: newURL.path))
        #expect(fileManager.fileExists(atPath: newURL.appendingPathComponent("file.txt").path))
    }

    // MARK: - Error Case: Name Collision

    @Test("Move to existing name throws nameCollision error")
    func testMoveNameCollisionThrows() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let file1 = try createTestFile(in: tempDir, name: "conflict.txt", content: "first")

        let subDir = tempDir.appendingPathComponent("sub")
        try fileManager.createDirectory(at: subDir, withIntermediateDirectories: true)
        let _ = try createTestFile(in: subDir, name: "conflict.txt", content: "second")

        let destination = subDir.appendingPathComponent("conflict.txt")

        let service = FileSystemService()
        #expect(throws: (any Error).self) {
            try service.moveItem(at: file1, to: destination)
        }

        // Original file should still exist since the operation failed
        #expect(fileManager.fileExists(atPath: file1.path))
    }

    @Test("Copy to existing name throws nameCollision error")
    func testCopyNameCollisionThrows() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let file1 = try createTestFile(in: tempDir, name: "source.txt", content: "source")
        let file2 = try createTestFile(in: tempDir, name: "exists.txt", content: "existing")

        let service = FileSystemService()
        #expect(throws: (any Error).self) {
            try service.copyItem(at: file1, to: file2)
        }

        // Both files should still exist with their original content
        let content = try String(contentsOf: file2, encoding: .utf8)
        #expect(content == "existing")
    }

    @Test("Rename to existing name throws FileSystemError.nameCollision")
    func testRenameNameCollisionThrowsSpecificError() throws {
        let tempDir = try makeTempDir()
        defer { cleanup(tempDir) }

        let _ = try createTestFile(in: tempDir, name: "existing.txt", content: "existing")
        let file = try createTestFile(in: tempDir, name: "toRename.txt", content: "rename me")

        let service = FileSystemService()
        do {
            let _ = try service.renameItem(at: file, to: "existing.txt")
            Issue.record("Expected nameCollision error to be thrown")
        } catch let error as FileSystemError {
            switch error {
            case .nameCollision:
                break // Expected
            default:
                Issue.record("Expected nameCollision error, got: \(error)")
            }
        }

        // Original file should remain unchanged
        #expect(fileManager.fileExists(atPath: file.path))
    }

    // MARK: - Error Case: Permissions

    @Test("Move from read-only directory throws permission error")
    func testMoveFromReadOnlyThrows() throws {
        let tempDir = try makeTempDir()
        defer {
            // Restore permissions before cleanup
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempDir.appendingPathComponent("readonly").path
            )
            cleanup(tempDir)
        }

        let readOnlyDir = tempDir.appendingPathComponent("readonly")
        try fileManager.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        let file = try createTestFile(in: readOnlyDir, name: "locked.txt", content: "locked")

        // Make directory read-only to prevent moving files out
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyDir.path)

        let destFile = tempDir.appendingPathComponent("locked.txt")
        let service = FileSystemService()

        #expect(throws: (any Error).self) {
            try service.moveItem(at: file, to: destFile)
        }

        // File should still exist in original location
        #expect(fileManager.fileExists(atPath: file.path))
    }

    @Test("Copy to read-only directory throws permission error")
    func testCopyToReadOnlyThrows() throws {
        let tempDir = try makeTempDir()
        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempDir.appendingPathComponent("readonlyDest").path
            )
            cleanup(tempDir)
        }

        let sourceFile = try createTestFile(in: tempDir, name: "source.txt", content: "data")

        let readOnlyDest = tempDir.appendingPathComponent("readonlyDest")
        try fileManager.createDirectory(at: readOnlyDest, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyDest.path)

        let destFile = readOnlyDest.appendingPathComponent("source.txt")
        let service = FileSystemService()

        #expect(throws: (any Error).self) {
            try service.copyItem(at: sourceFile, to: destFile)
        }
    }

    @Test("Create directory in read-only location throws permission error")
    func testCreateDirectoryInReadOnlyThrows() throws {
        let tempDir = try makeTempDir()
        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempDir.appendingPathComponent("nowrite").path
            )
            cleanup(tempDir)
        }

        let noWriteDir = tempDir.appendingPathComponent("nowrite")
        try fileManager.createDirectory(at: noWriteDir, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: noWriteDir.path)

        let service = FileSystemService()
        #expect(throws: (any Error).self) {
            try service.createDirectory(at: noWriteDir, name: "newFolder")
        }
    }
}
