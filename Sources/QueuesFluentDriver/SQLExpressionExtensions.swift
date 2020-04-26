import Fluent
import SQLKit

enum SQLSkipLocked: SQLExpression {
    case forUpdateSkipLocked
    case forShareSkipLocked
    
    public func serialize(to serializer: inout SQLSerializer) {
        switch self {
            case .forUpdateSkipLocked:
                serializer.write("FOR UPDATE SKIP LOCKED")
            case .forShareSkipLocked:
                // This is the "lightest" locking that is supported by both Postgres and Mysql
                serializer.write("FOR SHARE SKIP LOCKED")
        }
    }
}

enum SqlReturning : SQLExpression {
    /// `RETURNING *`
    case all
    case column(_ column: FieldKey)
    case sqlColumn(_ column: SQLColumn)
    
    public func serialize(to serializer: inout SQLSerializer) {
        switch self {
            case .all:
                serializer.write("RETURNING *")
            case .column(let column):
                serializer.write("RETURNING ")
                SQLColumn(column.description).serialize(to: &serializer)
            case .sqlColumn(let column):
                serializer.write("RETURNING ")
                column.serialize(to: &serializer)
        }
    }
}

struct SQLUpdateReturningExpression: SQLExpression {
    public let left: SQLExpression
    public let right: SQLExpression
    
    public init(left: SQLExpression, right: SqlReturning) {
        self.left = left
        self.right = right
    }
    
    public func serialize(to serializer: inout SQLSerializer) {
        self.left.serialize(to: &serializer)
        serializer.write(" ")
        self.right.serialize(to: &serializer)
        
    }
}

extension SQLUpdateBuilder {
    func returning(_ expression: SqlReturning) -> Self {
        if let existing = self.predicate {
            self.predicate = SQLUpdateReturningExpression(
                left: existing,
                right: expression
            )
        } else {
            self.predicate = expression
        }
        return self
    }
}
