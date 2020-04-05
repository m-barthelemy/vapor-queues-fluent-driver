import Fluent
import Queues


public enum QueuesFluentDbType {
    case postgres
    case mysql
    case sqlite
}

public struct FluentQueuesDriver {
    let databaseId: DatabaseID
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
    
    init(on databaseId: DatabaseID, dbType: QueuesFluentDbType, useSoftDeletes: Bool) {
        self.databaseId = databaseId
        self.dbType = dbType
        self.useSoftDeletes = useSoftDeletes
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
            dbType: self.dbType
        )
    }
    
    public func shutdown() {}
}
