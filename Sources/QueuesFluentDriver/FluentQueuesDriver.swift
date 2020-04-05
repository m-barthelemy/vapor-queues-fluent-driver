import Fluent
import Queues

public struct FluentQueuesDriver {
    let database: Database
    let useSkipLocked: Bool
    let useSoftDeletes: Bool
    
    init(on database: Database, useSoftDeletes: Bool, useSkipLocked: Bool) {
        self.database = database
        self.useSkipLocked = useSkipLocked
        self.useSoftDeletes = useSoftDeletes
    }
}


extension FluentQueuesDriver: QueuesDriver {
    public func makeQueue(with context: QueueContext) -> Queue {
        
        let db = self.database.configuration
            .makeDriver(for: Databases.init(threadPool: NIOThreadPool.init(numberOfThreads: 4), on: context.eventLoop))
            .makeDatabase(with:
                DatabaseContext(configuration: self.database.configuration, logger: self.database.logger, eventLoop: context.eventLoop)
            )
        return FluentQueue(
            database: db,
            context: context,
            useForUpdateSkipLocked: self.useSkipLocked
        )
    }
    
    public func shutdown() {}
}
