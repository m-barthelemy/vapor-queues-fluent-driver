import Foundation
import SQLKit
import Fluent
import Queues

final class SqlitePop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<UUID?> {
        let database = db as! SQLDatabase
        return database.raw(SQLQueryString("BEGIN IMMEDIATE")).run().flatMap { void in
            var id: UUID?
            return database.execute(sql: select) { (row) -> Void in
                print("••• columns: \(row.allColumns)")
                id = try? row.decode(column: "\(FluentQueue.model.$id.key)", as: UUID.self)
            }
            .flatMap {
                if (id != nil) {
                    let updateQuery = database
                        .update(JobModel.schema)
                        .set(SQLColumn.init("\(FluentQueue.model.$state.key)"), to: SQLBind.init(JobState.processing))
                        .set(SQLColumn.init("\(FluentQueue.model.$updatedAt.path.first!)"), to: SQLBind.init(Date()))
                        .where(SQLColumn.init("\(FluentQueue.model.$id.key)"), .equal, SQLBind.init(id!))
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
        }
    }
}
