import Foundation
import SQLKit
import Fluent

// Currently broken
final class SqlitePop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        let db = db as! SQLDatabase
        //let beginImmediateTrxn = database.raw("BEGIN IMMEDIATE").
        
        //return database.raw(SQLQueryString("BEGIN IMMEDIATE")).run().flatMap { void in
            var id: String?
            return db.execute(sql: select) { (row) -> Void in
                id = try? row.decode(column: "\(FieldKey.jobId)", as: String.self)
            }
            .flatMap {
                guard let id = id else {
                    return db.eventLoop.makeSucceededFuture(nil)
                }
                let updateQuery = db
                    .update(JobModel.schema)
                    .set(SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
                    .set(SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
                    .where(SQLColumn("\(FieldKey.jobId)"), .equal, SQLBind(id))
                    .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
                    .query
                return db.execute(sql: updateQuery) { (row) in }
                    .map {
                        //return db.raw(SQLQueryString("COMMIT")).run().map {
                            return id
                        //}
                    }
            }
        //}
    }
}
