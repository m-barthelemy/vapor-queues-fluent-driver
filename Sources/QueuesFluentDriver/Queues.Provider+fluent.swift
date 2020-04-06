import Foundation
import Vapor
import Fluent
import Queues

extension Application.Queues.Provider {
    /// `database`: the Fluent `Database` already configured in your application.
    /// `dbType`: one of `.psql`, `.mysq;`, `.sqlite`
    /// `useSoftDeletes`: if set to `false`, really delete completed jobs insetad of using Fluent's default SoftDelete feature.
    /// **WARNING**: if set to `false`, with any database engine other than Sqlite, a given job could be picked by multiple workers, unless you only have one single Queues worker/process.
    /// `useSkipLocked` is `true` by default and is supported on Mysql >= 8.0.1, MariaDB >= 10.3, Postgres >= 9.5, Oracle >= 9i(?).
    /// Sqlite doesn't have nor need it since it uses full table locking on update. Other dbs are just too weird (SQL Server).
    public static func fluent(_ dbId: DatabaseID, useSoftDeletes: Bool = true) -> Self {
        .init {
            $0.queues.use(custom:
                FluentQueuesDriver(on: dbId, useSoftDeletes: useSoftDeletes)
            )
        }
    }
}
