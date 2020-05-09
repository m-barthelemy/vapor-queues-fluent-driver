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
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
    let eventLoopGroup: EventLoopGroup
    
    init(on databaseId: DatabaseID? = nil, useSoftDeletes: Bool, on: EventLoopGroup) {
        self.databaseId = databaseId
        self.useSoftDeletes = useSoftDeletes
        self.dbType = .postgresql
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
        let dialect = (db as? SQLDatabase)?.dialect.name ?? "unknown"
        let dbType = QueuesFluentDbType(rawValue: dialect) ?? .none
        
        return FluentQueue(
            context: context,
            db: db,
            dbType: dbType,
            useSoftDeletes: self.useSoftDeletes
        )
    }
    
    public func shutdown() {
        // What are we supposed to do here?
        try? self.eventLoopGroup.syncShutdownGracefully()
    }
}
