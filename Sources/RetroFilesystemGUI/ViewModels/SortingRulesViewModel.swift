import Foundation

/// ViewModel managing sorting rules creation, editing, and deletion for a specific directory.
/// Uses the Observation framework (@Observable) for SwiftUI bindings.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.6
@Observable
class SortingRulesViewModel {

    // MARK: - State

    /// The sorting rules for the current directory.
    var rules: [SortingRule] = []

    /// The rule currently being edited, or nil if not editing.
    var editingRule: SortingRule?

    /// A validation error message to display inline, or nil if no error.
    var validationError: String?

    /// The directory path this view model manages rules for.
    let directoryPath: String

    /// A user-facing error message for persistence failures.
    var errorMessage: String?

    // MARK: - Services

    private let storageService: SortingRulesStorageServiceProtocol

    // MARK: - Constants

    /// Maximum number of sorting rules allowed per directory.
    private static let maxRulesPerDirectory = 50

    /// Maximum pattern length for file extension rules.
    private static let maxExtensionLength = 20

    /// Maximum pattern length for name pattern rules.
    private static let maxNamePatternLength = 255

    // MARK: - Initialization

    /// Creates a new SortingRulesViewModel for a specific directory.
    /// - Parameters:
    ///   - directoryPath: The absolute path of the directory to manage rules for.
    ///   - storageService: The service used to persist sorting rules.
    init(directoryPath: String, storageService: SortingRulesStorageServiceProtocol) {
        self.directoryPath = directoryPath
        self.storageService = storageService
    }

    // MARK: - Public Methods

    /// Loads sorting rules for the current directory from persistent storage.
    func loadRules() {
        do {
            let store = try storageService.load()
            if let directoryRules = store.directories.first(where: { $0.directoryPath == directoryPath }) {
                rules = directoryRules.rules
            } else {
                rules = []
            }
            errorMessage = nil
        } catch {
            rules = []
            errorMessage = error.localizedDescription
        }
    }

    /// Adds a new sorting rule with the given type and pattern.
    /// - Parameters:
    ///   - ruleType: The type of sorting rule to create.
    ///   - pattern: The pattern string for the rule.
    /// - Returns: A `Result` indicating success or a validation error.
    @discardableResult
    func addRule(ruleType: SortingRuleType, pattern: String) -> Result<Void, SortingRuleValidationError> {
        // Validate pattern
        let validationResult = validatePattern(pattern, for: ruleType)
        if case .failure(let error) = validationResult {
            validationError = errorMessage(for: error)
            return .failure(error)
        }

        // Check max rules cap
        if rules.count >= Self.maxRulesPerDirectory {
            let error = SortingRuleValidationError.maxRulesReached
            validationError = errorMessage(for: error)
            return .failure(error)
        }

        // Create and add the rule
        let newRule = SortingRule(
            id: UUID(),
            ruleType: ruleType,
            pattern: pattern,
            createdDate: Date()
        )
        rules.append(newRule)
        validationError = nil

        // Persist changes
        persistRules()

        return .success(())
    }

    /// Deletes a sorting rule by its ID.
    /// - Parameter id: The UUID of the rule to delete.
    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        persistRules()
    }

    /// Updates an existing sorting rule's type and pattern.
    /// - Parameters:
    ///   - id: The UUID of the rule to update.
    ///   - ruleType: The new rule type.
    ///   - pattern: The new pattern string.
    /// - Returns: A `Result` indicating success or a validation error.
    @discardableResult
    func updateRule(id: UUID, ruleType: SortingRuleType, pattern: String) -> Result<Void, SortingRuleValidationError> {
        // Validate pattern
        let validationResult = validatePattern(pattern, for: ruleType)
        if case .failure(let error) = validationResult {
            validationError = errorMessage(for: error)
            return .failure(error)
        }

        // Find and update the rule
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return .success(())
        }

        rules[index].ruleType = ruleType
        rules[index].pattern = pattern
        validationError = nil

        // Persist changes
        persistRules()

        return .success(())
    }

    // MARK: - Private Helpers

    /// Validates a pattern string for the given rule type.
    /// - Parameters:
    ///   - pattern: The pattern string to validate.
    ///   - ruleType: The rule type that determines validation constraints.
    /// - Returns: A `Result` indicating success or a validation error.
    private func validatePattern(_ pattern: String, for ruleType: SortingRuleType) -> Result<Void, SortingRuleValidationError> {
        // Check for empty pattern
        if pattern.isEmpty {
            return .failure(.emptyPattern)
        }

        // Check for pattern length based on rule type
        switch ruleType {
        case .fileExtension:
            if pattern.count > Self.maxExtensionLength {
                return .failure(.patternTooLong)
            }
        case .namePattern:
            if pattern.count > Self.maxNamePatternLength {
                return .failure(.patternTooLong)
            }
        case .tag:
            // Tag patterns are tag UUID strings; no length constraint beyond empty check
            break
        }

        return .success(())
    }

    /// Persists the current rules to storage.
    private func persistRules() {
        do {
            var store = try storageService.load()

            // Find or create the directory entry
            if let index = store.directories.firstIndex(where: { $0.directoryPath == directoryPath }) {
                store.directories[index] = DirectorySortingRules(
                    directoryPath: directoryPath,
                    rules: rules
                )
            } else {
                store.directories.append(DirectorySortingRules(
                    directoryPath: directoryPath,
                    rules: rules
                ))
            }

            try storageService.save(store)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns a user-facing error message for a validation error.
    /// - Parameter error: The validation error.
    /// - Returns: A descriptive error string.
    private func errorMessage(for error: SortingRuleValidationError) -> String {
        switch error {
        case .emptyPattern:
            return "Rule pattern cannot be empty"
        case .patternTooLong:
            return "Pattern exceeds maximum length"
        case .maxRulesReached:
            return "Maximum of 50 rules per directory reached"
        }
    }
}
