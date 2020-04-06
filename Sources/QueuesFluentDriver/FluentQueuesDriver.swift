import Fluent
import SQLKit
import Queues


public enum QueuesFluentDbType: String {
    case postgresql
    case mysql
    case sqlite
}

public struct FluentQueuesDriver {
    let databaseId: DatabaseID
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
    
    init(on databaseId: DatabaseID, useSoftDeletes: Bool) {
        self.databaseId = databaseId
        self.useSoftDeletes = useSoftDeletes
        self.dbType = .postgresql
    }
}

extension FluentQueuesDriver: QueuesDriver {
    public func makeQueue(with context: QueueContext) -> Queue {
        let db = context
            .application
            .databases
            .database(databaseId, logger: context.logger, on: context.eventLoop)
        return FluentQueue(
            db: db,
            context: context,
            dbType: QueuesFluentDbType(rawValue: (db as! SQLDatabase).dialect.name)!
        )
    }
    
    public func shutdown() {}
}
