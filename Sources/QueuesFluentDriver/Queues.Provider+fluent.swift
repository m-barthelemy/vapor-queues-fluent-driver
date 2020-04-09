import Foundation
import Vapor
import Fluent
import Queues

extension Application.Queues.Provider {
    /// `database`: the Fluent `Database` already configured in your application.
    /// `useSoftDeletes`: if set to `false`, really delete completed jobs insetad of using Fluent's default SoftDelete feature.
    public static func fluent(_ dbId: DatabaseID? = nil, useSoftDeletes: Bool = true) -> Self {
        .init {
            $0.queues.use(custom:
                FluentQueuesDriver(on: dbId, useSoftDeletes: useSoftDeletes)
            )
        }
    }
}
