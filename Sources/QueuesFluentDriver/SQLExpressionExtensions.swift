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

// We're really abusing here but not sure how to do it in a cleaner way
enum SQLReturning: SQLExpression {
    /// `RETURNING *`
    case returningAll
    case returning(column: FieldKey)
    
    public func serialize(to serializer: inout SQLSerializer) {
        switch self {
            case .returningAll:
                serializer.write("1=2 RETURNING *")
            case .returning(let column):
                serializer.write("1=2 RETURNING ")
                SQLColumn(column.description).serialize(to: &serializer)
        }
    }
}
