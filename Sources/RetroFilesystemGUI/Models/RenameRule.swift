import Foundation

enum RenameRule {
    case findReplace(find: String, replace: String)
    case sequentialNumbering(position: Position, start: Int, padding: Int)
    case dateInsertion(position: Position, dateSource: DateSource, format: String)

    enum Position {
        case prepend, append
    }

    enum DateSource {
        case creation, modification
    }
}
