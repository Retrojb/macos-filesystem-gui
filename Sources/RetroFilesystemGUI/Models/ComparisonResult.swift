import Foundation

struct ComparisonItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let size: Int64
    let modificationDate: Date
    let isDirectory: Bool
    let sourceURL: URL
}

struct DirectoryComparisonResult: Equatable {
    let directory1Name: String
    let directory2Name: String
    let directory1URL: URL
    let directory2URL: URL
    let uniqueToFirst: [ComparisonItem]
    let uniqueToSecond: [ComparisonItem]
    let inBoth: [ComparisonItem]
}
