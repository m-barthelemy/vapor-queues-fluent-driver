import Foundation
import SQLKit
import Fluent
import Queues

final class PostgresPop : PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        let database = db as! SQLDatabase
        let subQueryGroup = SQLGroupExpression.init(select)
        let query = database
            .update (JobModel.schema)
            .set    (SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
            .set    (SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
            .where  (
                SQLBinaryExpression(left: SQLColumn("\(FieldKey.jobId)"), op: SQLBinaryOperator.equal , right: subQueryGroup)
            )
            .returning(.column(FieldKey.jobId))
            .query
        
        var id: String?
        return database.execute(sql: query) { (row) -> Void in
            id = try? row.decode(column: "\(FieldKey.jobId)", as: String.self)
        }.map {
            return id
        }
    }
}
