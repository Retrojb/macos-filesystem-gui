import Foundation
import UniformTypeIdentifiers

/// Errors that can occur during file system operations.
enum FileSystemError: LocalizedError {
    case directoryNotFound(URL)
    case permissionDenied(URL)
    case diskFull
    case nameCollision(URL)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let url):
            return "The directory '\(url.lastPathComponent)' does not exist or is inaccessible."
        case .permissionDenied(let url):
            return "Permission denied for '\(url.lastPathComponent)'. Check your access privileges."
        case .diskFull:
            return "The operation could not be completed because the disk is full."
        case .nameCollision(let url):
            return "An item named '\(url.lastPathComponent)' already exists at the destination."
        case .operationFailed(let message):
            return message
        }
    }
}

/// Concrete implementation of `FileSystemServiceProtocol` using `FileManager`.
class FileSystemService: FileSystemServiceProtocol {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Directory Listing

    func contentsOfDirectory(at url: URL, showHidden: Bool) throws -> [FileItem] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.directoryNotFound(url)
        }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard isDirectory.boolValue else {
            throw FileSystemError.directoryNotFound(url)
        }

        let resourceKeys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentTypeKey,
            .isDirectoryKey,
            .isHiddenKey,
            .localizedNameKey
        ]

        let contents: [URL]
        do {
            var options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
            if !showHidden {
                options.insert(.skipsHiddenFiles)
            }
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: options
            )
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileReadNoPermissionError, NSFileReadNoSuchFileError:
                    throw FileSystemError.permissionDenied(url)
                default:
                    break
                }
            }
            throw mapError(error, url: url)
        }

        return contents.compactMap { fileURL in
            createFileItem(from: fileURL)
        }
    }

    // MARK: - Move

    func moveItem(at source: URL, to destination: URL) throws {
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch let error as NSError {
            throw mapError(error, url: source)
        }
    }

    // MARK: - Copy

    func copyItem(at source: URL, to destination: URL) throws {
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch let error as NSError {
            throw mapError(error, url: source)
        }
    }

    // MARK: - Trash

    func trashItem(at url: URL) throws {
        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } catch let error as NSError {
            throw mapError(error, url: url)
        }
    }

    // MARK: - Create Directory

    @discardableResult
    func createDirectory(at url: URL, name: String) throws -> URL {
        let newDirectoryURL = url.appendingPathComponent(name)

        if fileManager.fileExists(atPath: newDirectoryURL.path) {
            throw FileSystemError.nameCollision(newDirectoryURL)
        }

        do {
            try fileManager.createDirectory(
                at: newDirectoryURL,
                withIntermediateDirectories: false,
                attributes: nil
            )
        } catch let error as NSError {
            throw mapError(error, url: newDirectoryURL)
        }

        return newDirectoryURL
    }

    // MARK: - Rename

    @discardableResult
    func renameItem(at url: URL, to newName: String) throws -> URL {
        let parentDirectory = url.deletingLastPathComponent()
        let destinationURL = parentDirectory.appendingPathComponent(newName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            throw FileSystemError.nameCollision(destinationURL)
        }

        do {
            try fileManager.moveItem(at: url, to: destinationURL)
        } catch let error as NSError {
            throw mapError(error, url: url)
        }

        return destinationURL
    }

    // MARK: - Existence Check

    func itemExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Private Helpers

    /// Maps a file URL to a `FileItem` by reading its resource values.
    private func createFileItem(from url: URL) -> FileItem? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .contentTypeKey,
                .isDirectoryKey,
                .isHiddenKey
            ])

            let isDirectory = resourceValues.isDirectory ?? false
            let size = Int64(resourceValues.fileSize ?? 0)
            let modificationDate = resourceValues.contentModificationDate ?? Date.distantPast
            let creationDate = resourceValues.creationDate ?? Date.distantPast
            let isHidden = resourceValues.isHidden ?? false
            let kind = kindString(for: resourceValues.contentType, isDirectory: isDirectory)

            return FileItem(
                id: UUID(),
                url: url,
                name: url.lastPathComponent,
                isDirectory: isDirectory,
                size: size,
                modificationDate: modificationDate,
                creationDate: creationDate,
                kind: kind,
                isHidden: isHidden
            )
        } catch {
            // If we can't read resource values, skip this item
            return nil
        }
    }

    /// Derives a human-readable kind string from a content type.
    private func kindString(for contentType: UTType?, isDirectory: Bool) -> String {
        if isDirectory {
            return "Folder"
        }
        guard let type = contentType else {
            return "Document"
        }
        return type.localizedDescription ?? type.preferredFilenameExtension?.uppercased() ?? "Document"
    }

    /// Maps an NSError to a structured `FileSystemError`.
    private func mapError(_ error: NSError, url: URL) -> FileSystemError {
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .directoryNotFound(url)
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .permissionDenied(url)
            case NSFileWriteOutOfSpaceError:
                return .diskFull
            case NSFileWriteFileExistsError:
                return .nameCollision(url)
            default:
                break
            }
        }

        if error.domain == NSPOSIXErrorDomain {
            switch error.code {
            case 13: // EACCES
                return .permissionDenied(url)
            case 28: // ENOSPC
                return .diskFull
            case 17: // EEXIST
                return .nameCollision(url)
            default:
                break
            }
        }

        return .operationFailed(error.localizedDescription)
    }
}
