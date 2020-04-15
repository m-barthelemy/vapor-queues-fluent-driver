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
            .set    (SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
            .set    (SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
            .where  (
                SQLBinaryExpression(left: SQLColumn("\(FieldKey.id)"), op: SQLBinaryOperator.equal , right: subQueryGroup)
            )
            // Gross abuse
            .orWhere(SQLReturning.returning(column: FieldKey.id))
            .query
        
        var id: UUID?
        return database.execute(sql: query) { (row) -> Void in
            id = try? row.decode(column: "\(FieldKey.id)", as: UUID.self)
        }
        .map {
            return id
        }
    }
}
