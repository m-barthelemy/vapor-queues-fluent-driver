import Foundation
import Fluent

// Put here for reference
// This implementation is working, but disabled since using raw SQL

/*
private func pop(_ id: JobIdentifier? = nil) -> EventLoopFuture<JobIdentifier?> {
    let db = self.database as! PostgresDatabase
    let lockclause = self.useForUpdateSkipLocked ? "FOR UPDATE SKIP LOCKED" : ""
    let sql =   """
                UPDATE \(JobModel.schema)
                SET "\(Self.model.$state.key)" = '\(JobState.processing)',
                "\(Self.model.$updatedAt.path.first!)" = CURRENT_TIMESTAMP
                WHERE "\(Self.model.$id.key)" = (
                    SELECT "\(Self.model.$id.key)"
                    FROM "\(JobModel.schema)"
                    WHERE "\(Self.model.$state.key)" = '\(JobState.pending)'
                    ORDER BY "\(Self.model.$createdAt.path.first!)"
                    \(lockclause)
                    LIMIT 1
                )
                RETURNING *
                """
    
    return db.sql().raw(SQLQueryString.init(sql) )
        .first(decoding: JobModel.self).optionalMap {
            return JobIdentifier(string: $0.id!.uuidString)
    }
}
*/
