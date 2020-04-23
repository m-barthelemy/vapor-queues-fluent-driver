import Foundation
import SQLKit
import Fluent
import Queues

final class SqlitePop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        let database = db as! SQLDatabase
        //let beginImmediateTrxn = database.raw("BEGIN IMMEDIATE").
        
        //return database.raw(SQLQueryString("BEGIN IMMEDIATE")).run().flatMap { void in
            var id: String?
            return database.execute(sql: select) { (row) -> Void in
                id = try? row.decode(column: "\(FieldKey.jobId)", as: String.self)
            }
            .flatMap {
                if let id = id {
                    let updateQuery = database
                        .update (JobModel.schema)
                        .set    (SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
                        .set    (SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
                        .where  (SQLColumn("\(FieldKey.jobId)"), .equal, SQLBind(id))
                        .where  (SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
                        .query
                    return database.execute(sql: updateQuery) { (row) in }
                        .flatMap {
                            return database.raw(SQLQueryString("COMMIT")).run().map {
                                return id
                            }
                        }
                }
                return database.eventLoop.makeSucceededFuture(nil)
            }
        //}
    }
}
