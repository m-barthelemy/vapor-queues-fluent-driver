import Fluent
import Queues

public struct FluentQueuesDriver {
    let databaseId: DatabaseID
    let useSkipLocked: Bool
    let useSoftDeletes: Bool
    
    init(on databaseId: DatabaseID, useSoftDeletes: Bool, useSkipLocked: Bool) {
        self.databaseId = databaseId
        self.useSkipLocked = useSkipLocked
        self.useSoftDeletes = useSoftDeletes
    }
}

extension FluentQueuesDriver: QueuesDriver {
    public func makeQueue(with context: QueueContext) -> Queue {
        let db = context.application.databases.database(databaseId, logger: context.logger, on: context.eventLoop)
        return FluentQueue(
            db: db,
            context: context,
            useForUpdateSkipLocked: self.useSkipLocked
        )
    }
    
    public func shutdown() {}
}
