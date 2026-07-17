import Foundation

/// Errors that can occur during tag management operations.
enum TagError: Error, Equatable {
    /// The tag name is empty (less than 1 character).
    case nameTooShort
    /// The tag name exceeds 64 characters.
    case nameTooLong
    /// Another tag with the same name already exists (case-insensitive).
    case duplicateName
    /// The specified tag ID was not found in the store.
    case tagNotFound
}

/// Provides in-memory mutation operations on a `TagStore`.
///
/// All methods validate inputs and return updated stores or throw errors.
/// The `TagManager` operates as a pure logic layer — persistence is handled
/// separately by `TagStorageServiceProtocol`.
struct TagManager {

    // MARK: - Tag CRUD

    /// Creates a new tag with the given name and color after validation.
    ///
    /// - Parameters:
    ///   - name: The tag name (must be 1–64 characters).
    ///   - color: The tag color.
    ///   - store: The current tag store.
    /// - Returns: A `Result` containing the newly created `Tag` on success,
    ///   or a `TagError` on validation failure.
    func createTag(name: String, color: TagColor, in store: inout TagStore) -> Result<Tag, TagError> {
        switch validateName(name, excludingTagId: nil, in: store) {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        let tag = Tag(id: UUID(), name: name, color: color)
        store.tags.append(tag)
        return .success(tag)
    }

    /// Edits an existing tag's name and/or color.
    ///
    /// - Parameters:
    ///   - id: The ID of the tag to edit.
    ///   - name: The new tag name (must be 1–64 characters, unique excluding self).
    ///   - color: The new tag color.
    ///   - store: The current tag store.
    /// - Returns: A `Result` indicating success or a `TagError`.
    func editTag(id: UUID, name: String, color: TagColor, in store: inout TagStore) -> Result<Void, TagError> {
        guard let index = store.tags.firstIndex(where: { $0.id == id }) else {
            return .failure(.tagNotFound)
        }

        switch validateName(name, excludingTagId: id, in: store) {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        store.tags[index].name = name
        store.tags[index].color = color
        return .success(())
    }

    /// Deletes a tag and removes all its associations.
    ///
    /// - Parameters:
    ///   - id: The ID of the tag to delete.
    ///   - store: The current tag store.
    /// - Returns: A `Result` indicating success or `.tagNotFound` if the ID doesn't exist.
    func deleteTag(id: UUID, from store: inout TagStore) -> Result<Void, TagError> {
        guard store.tags.contains(where: { $0.id == id }) else {
            return .failure(.tagNotFound)
        }

        store.tags.removeAll { $0.id == id }
        store.associations.removeAll { $0.tagId == id }
        return .success(())
    }

    // MARK: - Tag Assignment

    /// Assigns a tag to a file path. This operation is idempotent — assigning
    /// a tag that is already assigned produces no error and no duplicate.
    ///
    /// - Parameters:
    ///   - tagId: The ID of the tag to assign.
    ///   - filePath: The file path to associate with the tag.
    ///   - store: The current tag store.
    /// - Returns: A `Result` indicating success or `.tagNotFound` if the tag ID doesn't exist.
    func assignTag(tagId: UUID, to filePath: String, in store: inout TagStore) -> Result<Void, TagError> {
        guard store.tags.contains(where: { $0.id == tagId }) else {
            return .failure(.tagNotFound)
        }

        let association = TagAssociation(filePath: filePath, tagId: tagId)
        if !store.associations.contains(association) {
            store.associations.append(association)
        }
        return .success(())
    }

    /// Removes a tag association from a file path. If the association does not
    /// exist, this is a no-op (no error).
    ///
    /// - Parameters:
    ///   - tagId: The ID of the tag to remove.
    ///   - filePath: The file path to disassociate from the tag.
    ///   - store: The current tag store.
    /// - Returns: A `Result` indicating success or `.tagNotFound` if the tag ID doesn't exist.
    func removeTag(tagId: UUID, from filePath: String, in store: inout TagStore) -> Result<Void, TagError> {
        guard store.tags.contains(where: { $0.id == tagId }) else {
            return .failure(.tagNotFound)
        }

        store.associations.removeAll { $0.tagId == tagId && $0.filePath == filePath }
        return .success(())
    }

    // MARK: - Validation

    /// Validates a tag name against length and uniqueness constraints.
    ///
    /// - Parameters:
    ///   - name: The proposed tag name.
    ///   - excludingTagId: An optional tag ID to exclude from uniqueness check (for edits).
    ///   - store: The current tag store.
    /// - Returns: `.success` if valid, or a `TagError` describing the failure.
    private func validateName(_ name: String, excludingTagId: UUID?, in store: TagStore) -> Result<Void, TagError> {
        guard !name.isEmpty else {
            return .failure(.nameTooShort)
        }

        guard name.count <= 64 else {
            return .failure(.nameTooLong)
        }

        let lowercasedName = name.lowercased()
        let isDuplicate = store.tags.contains { tag in
            if let excludeId = excludingTagId, tag.id == excludeId {
                return false
            }
            return tag.name.lowercased() == lowercasedName
        }

        if isDuplicate {
            return .failure(.duplicateName)
        }

        return .success(())
    }
}
