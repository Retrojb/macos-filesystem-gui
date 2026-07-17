import Foundation

/// ViewModel providing tag management operations to SwiftUI views.
///
/// Uses the `TagManager` struct for validation and mutation logic,
/// and `TagStorageServiceProtocol` for persistence. Tags are exposed
/// sorted alphabetically (case-insensitive, locale-aware) for display.
@Observable
class TagManagerViewModel {

    // MARK: - Published State

    /// All tags sorted alphabetically by name (case-insensitive, locale-aware).
    private(set) var tags: [Tag] = []

    /// All tag-to-file associations.
    private(set) var associations: [TagAssociation] = []

    /// Error message displayed to the user, cleared on next successful operation.
    var errorMessage: String?

    // MARK: - Private

    private let storageService: TagStorageServiceProtocol
    private let tagManager = TagManager()
    private var store = TagStore(tags: [], associations: [])

    /// Maximum number of tags allowed per file.
    private let maxTagsPerFile = 20

    // MARK: - Initialization

    /// Creates a new TagManagerViewModel.
    ///
    /// - Parameter storageService: The storage service used for persistence.
    init(storageService: TagStorageServiceProtocol) {
        self.storageService = storageService
        loadStore()
    }

    // MARK: - Tag CRUD

    /// Creates a new tag with the given name and color.
    ///
    /// - Parameters:
    ///   - name: The tag name (1–64 characters, unique case-insensitive).
    ///   - color: The tag color.
    /// - Returns: The newly created `Tag` on success, or a `TagError` on failure.
    @discardableResult
    func createTag(name: String, color: TagColor) -> Result<Tag, TagError> {
        let result = tagManager.createTag(name: name, color: color, in: &store)
        switch result {
        case .success:
            syncState()
            saveStore()
        case .failure(let error):
            errorMessage = describeError(error)
        }
        return result
    }

    /// Edits an existing tag's name and/or color.
    ///
    /// - Parameters:
    ///   - id: The ID of the tag to edit.
    ///   - name: The new name (if nil, keeps current name).
    ///   - color: The new color (if nil, keeps current color).
    /// - Returns: Success or a `TagError`.
    @discardableResult
    func editTag(id: UUID, name: String? = nil, color: TagColor? = nil) -> Result<Void, TagError> {
        guard let existingTag = store.tags.first(where: { $0.id == id }) else {
            let error = TagError.tagNotFound
            errorMessage = describeError(error)
            return .failure(error)
        }

        let newName = name ?? existingTag.name
        let newColor = color ?? existingTag.color

        let result = tagManager.editTag(id: id, name: newName, color: newColor, in: &store)
        switch result {
        case .success:
            syncState()
            saveStore()
        case .failure(let error):
            errorMessage = describeError(error)
        }
        return result
    }

    /// Deletes a tag and all its associations.
    ///
    /// - Parameter id: The ID of the tag to delete.
    func deleteTag(id: UUID) {
        let result = tagManager.deleteTag(id: id, from: &store)
        switch result {
        case .success:
            syncState()
            saveStore()
        case .failure(let error):
            errorMessage = describeError(error)
        }
    }

    // MARK: - Tag Assignment

    /// Assigns a tag to one or more file paths.
    ///
    /// Enforces a maximum of 20 tags per file. If assigning would exceed
    /// the limit, the operation is skipped for that file and an error is set.
    ///
    /// - Parameters:
    ///   - tagId: The ID of the tag to assign.
    ///   - filePaths: The file paths to assign the tag to.
    func assignTag(_ tagId: UUID, to filePaths: [String]) {
        for filePath in filePaths {
            let currentTagCount = store.associations.filter { $0.filePath == filePath }.count
            let alreadyAssigned = store.associations.contains(
                TagAssociation(filePath: filePath, tagId: tagId)
            )

            if !alreadyAssigned && currentTagCount >= maxTagsPerFile {
                errorMessage = "Cannot assign more than \(maxTagsPerFile) tags to a file."
                continue
            }

            let result = tagManager.assignTag(tagId: tagId, to: filePath, in: &store)
            if case .failure(let error) = result {
                errorMessage = describeError(error)
                return
            }
        }
        syncState()
        saveStore()
    }

    /// Removes a tag from one or more file paths.
    ///
    /// - Parameters:
    ///   - tagId: The ID of the tag to remove.
    ///   - filePaths: The file paths to remove the tag from.
    func removeTag(_ tagId: UUID, from filePaths: [String]) {
        for filePath in filePaths {
            let result = tagManager.removeTag(tagId: tagId, from: filePath, in: &store)
            if case .failure(let error) = result {
                errorMessage = describeError(error)
                return
            }
        }
        syncState()
        saveStore()
    }

    // MARK: - Queries

    /// Returns the tags assigned to a file, sorted alphabetically.
    ///
    /// - Parameter filePath: The file path to look up.
    /// - Returns: An array of `Tag` objects sorted by name (case-insensitive, locale-aware).
    func tagsForFile(_ filePath: String) -> [Tag] {
        let tagIds = store.associations
            .filter { $0.filePath == filePath }
            .map { $0.tagId }

        let matchingTags = store.tags.filter { tagIds.contains($0.id) }
        return matchingTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Returns file paths whose tags are a superset of the given tag IDs.
    ///
    /// - Parameter tagIds: The tag IDs to filter by.
    /// - Returns: File paths that have ALL of the specified tags assigned.
    func filesMatchingTags(_ tagIds: [UUID]) -> [String] {
        guard !tagIds.isEmpty else { return [] }

        let tagIdSet = Set(tagIds)

        // Group associations by file path
        var fileTagMap: [String: Set<UUID>] = [:]
        for association in store.associations {
            fileTagMap[association.filePath, default: []].insert(association.tagId)
        }

        // Return files whose tag set is a superset of the selected tag IDs
        return fileTagMap
            .filter { $0.value.isSuperset(of: tagIdSet) }
            .map { $0.key }
            .sorted()
    }

    // MARK: - Private Helpers

    /// Loads the tag store from persistence.
    private func loadStore() {
        do {
            store = try storageService.load()
            syncState()
        } catch {
            errorMessage = "Failed to load tags: \(error.localizedDescription)"
            store = TagStore(tags: [], associations: [])
            syncState()
        }
    }

    /// Saves the tag store to persistence.
    private func saveStore() {
        do {
            try storageService.save(store)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save tags: \(error.localizedDescription)"
        }
    }

    /// Syncs published state from the internal store, applying alphabetical sort.
    private func syncState() {
        tags = store.tags.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        associations = store.associations
    }

    /// Returns a user-facing description for a tag error.
    private func describeError(_ error: TagError) -> String {
        switch error {
        case .nameTooShort:
            return "Tag name cannot be empty."
        case .nameTooLong:
            return "Tag name cannot exceed 64 characters."
        case .duplicateName:
            return "A tag with that name already exists."
        case .tagNotFound:
            return "The specified tag was not found."
        }
    }
}
