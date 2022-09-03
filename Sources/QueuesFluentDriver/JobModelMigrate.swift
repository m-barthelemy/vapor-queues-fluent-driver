import Foundation
import Fluent
import SQLKit

public struct JobModelMigrate: Migration {
    public init() {}
    
    public init(schema: String) {
        JobModel.schema = schema
    }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobModel.schema)
            .id()
            .field(FieldKey.queue,     .string, .required)
            .field(FieldKey.state,     .string, .required)
            .field(FieldKey.createdAt, .datetime)
            .field(FieldKey.updatedAt, .datetime)
            .field(FieldKey.deletedAt, .datetime)
            .create()
            .flatMap {
                // Mysql could lock the entire table if there's no index on the fields of the WHERE clause.
                // Since we have both state and queue in the WHERE clause to retrieve pending jobs,
                //  both need to be part of a composite index.
                // Order of the fields in the composite index and order of the fields in the WHERE clauses should match.
                // Or I got totally confused reading their doc, which is also a possibility.
                // Postgres seems to not be so sensitive and should be happy with the following indices.
                let sqlDb = database as! SQLDatabase
                let stateIndex =  sqlDb.create(index: "i_\(JobModel.schema)_\(FieldKey.state)_\(FieldKey.queue)")
                    .on(JobModel.schema)
                    .column("\(FieldKey.state)")
                    .column("\(FieldKey.queue)")
                    .run()
                return stateIndex.map { index in
                    return
                }
            }
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobModel.schema).delete()
    }
}
