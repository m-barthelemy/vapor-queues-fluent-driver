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
        FluentQueue(
            database: self.database,
            context: context,
            useForUpdateSkipLocked: self.useSkipLocked
        )
    }
    
    public func shutdown() {}
}
