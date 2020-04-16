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
                id = try? row.decode(column: "\(FieldKey.id)", as: UUID.self)
            }
            .flatMap {
                if let id = id {
                    let updateQuery = database
                        .update(JobModel.schema)
                        .set(SQLColumn.init("\(FieldKey.state)"), to: SQLBind.init(QueuesFluentJobState.processing))
                        .set(SQLColumn.init("\(FieldKey.updatedAt)"), to: SQLBind.init(Date()))
                        .where(SQLColumn.init("\(FieldKey.id)"), .equal, SQLBind.init(id))
                        .query
                    return database.execute(sql: updateQuery) { (row) in }
                        .map { id }
                }
                return database.eventLoop.makeSucceededFuture(nil)
            }
            
        }
    }
}
