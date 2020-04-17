import Foundation
import SQLKit
import Fluent
import Queues

final class MySQLPop : PopQueryProtocol {
    // MySQL is a bit challenging since it doesn't support updating a table that is
    //  used in a subquery.
    // So we first select, then update, with the whole process wrapped in a transaction.
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        db.transaction { transaction in
            let database = transaction as! SQLDatabase
            var id: String?

            return database.execute(sql: select) { (row) -> Void in
                id = try? row.decode(column: "\(FieldKey.jobId)", as: String.self)
            }
            .flatMap {
                if let id = id {
                    let updateQuery = database
                        .update (JobModel.schema)
                        .set    (SQLColumn.init("\(FieldKey.state)"), to: SQLBind.init(QueuesFluentJobState.processing))
                        .set    (SQLColumn.init("\(FieldKey.updatedAt)"), to: SQLBind.init(Date()))
                        .where  (SQLColumn.init("\(FieldKey.jobId)"), .equal, SQLBind.init(id))
                        .where  (SQLColumn.init("\(FieldKey.state)"), .equal, SQLBind.init(QueuesFluentJobState.pending))
                        .query
                    return database.execute(sql: updateQuery) { (row) in }
                        .map { id }
                }
                return database.eventLoop.makeSucceededFuture(nil)
            }
            
        }
    }
}
