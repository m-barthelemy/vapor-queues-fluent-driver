import Foundation
import SQLKit
import Fluent

final class SqlitePop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        db.transaction { transaction in
            let database = transaction as! SQLDatabase
            var id: String?

            return database.execute(sql: select) { (row) -> Void in
                id = try? row.decode(column: "\(FieldKey.jobId)", as: String.self)
            }
            .flatMap {
                guard let id = id else {
                    return database.eventLoop.makeSucceededFuture(nil)
                }
                let updateQuery = database
                    .update(JobModel.schema)
                    .set(SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
                    .set(SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
                    .where(SQLColumn("\(FieldKey.jobId)"), .equal, SQLBind(id))
                    .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
                    .query
                return database.execute(sql: updateQuery) { (row) in }
                    .map { id }
            }

        }
    }
}
