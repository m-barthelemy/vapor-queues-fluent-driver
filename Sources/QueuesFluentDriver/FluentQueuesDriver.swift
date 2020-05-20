import Fluent
import SQLKit
import Queues

public enum QueuesFluentDbType: String {
    case postgresql
    case mysql
    case sqlite
}

public struct FluentQueuesDriver {
    let databaseId: DatabaseID?
    let useSoftDeletes: Bool
    let eventLoopGroup: EventLoopGroup
    
    init(on databaseId: DatabaseID? = nil, useSoftDeletes: Bool, on: EventLoopGroup) {
        self.databaseId = databaseId
        self.useSoftDeletes = useSoftDeletes
        self.eventLoopGroup = on
    }
}

extension FluentQueuesDriver: QueuesDriver {
    public func makeQueue(with context: QueueContext) -> Queue {
        let db = context
            .application
            .databases
            .database(databaseId, logger: context.logger, on: context.eventLoop)
        
        // How do we report that something goes wrong here? Since makeQueue cannot throw.
        let dialect = (db as? SQLDatabase)?.dialect.name
        if db == nil || dialect == nil {
            context.logger.error(
                "\(Self.self): Database misconfigured or unsupported."
            )
        }
        
        let dbType = QueuesFluentDbType(rawValue: dialect!)
        if dbType == nil {
            context.logger.error("\(Self.self): Unsupported Database type '\(dialect!)'")
        }
        
        return FluentQueue(
            context: context,
            db: db!,
            dbType: dbType!,
            useSoftDeletes: self.useSoftDeletes
        )
    }
    
    public func shutdown() {
    }
}
