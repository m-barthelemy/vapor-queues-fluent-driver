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
            .field(FieldKey.key,       .string, .required)
            .field(FieldKey.data,      .data,   .required)
            .field(FieldKey.state,     .string, .required)
            .field(FieldKey.createdAt, .datetime)
            .field(FieldKey.updatedAt, .datetime)
            .field(FieldKey.deletedAt, .datetime)
            .create()
            .flatMap {
                // Mysql could lock the entire table if there's no index on the field of the WHERE clause
                let sqlDb = database as! SQLDatabase
                return sqlDb.create(index: "i_\(JobModel.schema)_\(FieldKey.state)")
                    .on(JobModel.schema)
                    .column("\(FieldKey.state)")
                    .run()
            }
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobModel.schema).delete()
    }
}
