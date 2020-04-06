import Foundation
import SQLKit
import Fluent
import Queues

final class MySQLPop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<UUID?> {
        db.transaction { transaction in
            let database = transaction as! SQLDatabase
                        
            var id: UUID?
            return database.execute(sql: select) { (row) -> Void in
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
                        .map { id }
                }
                return database.eventLoop.makeSucceededFuture(nil)
            }
            
        }
    }
}
