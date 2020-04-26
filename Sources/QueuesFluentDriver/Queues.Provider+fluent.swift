import Foundation
import Vapor
import Fluent
import Queues

extension Application.Queues.Provider {
    /// `databaseId`: a Fluent `DatabaseID` configured in your application.
    /// `useSoftDeletes`: if set to `false`, really delete completed jobs insetad of using Fluent's default SoftDelete feature.
    public static func fluent(_ databaseId: DatabaseID? = nil, useSoftDeletes: Bool = true) -> Self {
        .init {
            $0.queues.use(custom:
                FluentQueuesDriver(on: databaseId, useSoftDeletes: useSoftDeletes, on: $0.eventLoopGroup)
            )
        }
    }
}
