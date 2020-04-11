import Foundation
import SQLKit
import Fluent
import Queues

final class PostgresPop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<UUID?> {
        let database = db as! SQLDatabase
        let subQueryGroup = SQLGroupExpression.init(select)
        let query = database
            .update (JobModel.schema)
            .set    (SQLColumn("\(FluentQueue.model.$state.key)"), to: SQLBind(QueuesFluentJobState.processing))
            .set    (SQLColumn("\(FluentQueue.model.$updatedAt.path.first!)"), to: SQLBind(Date()))
            .where  (
                SQLBinaryExpression(left: SQLColumn("\(FluentQueue.model.$id.key)"), op: SQLBinaryOperator.equal , right: subQueryGroup)
            )
            // Gross abuse
            .orWhere(SQLReturning.returning(column: FluentQueue.model.$id.key))
            .query
        
        var id: UUID?
        return database.execute(sql: query) { (row) -> Void in
            id = try? row.decode(column: "\(FluentQueue.model.$id.key)", as: UUID.self)
        }
        .map {
            return id
        }
    }
}
