import Foundation
import Vapor
import Fluent
import Queues

extension Application.Queues.Provider {
    /// `databaseId`: a Fluent `DatabaseID` configured in your application.
    /// `useSoftDeletes`: if set to `true`, flag completed jobs using Fluent's default SoftDelete feature instead of actually deleting them.
    public static func fluent(_ databaseId: DatabaseID? = nil, useSoftDeletes: Bool = false) -> Self {
        .init {
            $0.queues.use(custom:
                FluentQueuesDriver(on: databaseId, useSoftDeletes: useSoftDeletes, on: $0.eventLoopGroup)
            )
        }
    }
}
