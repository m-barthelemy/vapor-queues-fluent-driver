import Foundation
import Fluent
import SQLKit

public struct JobModelMigrate: Migration {
    public init() {}
    
    public init(schema: String) {
        JobModel.schema = schema
    }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        let model = FluentQueue.model
        return database.schema(JobModel.schema)
            .id()
            .field(model.$key.key,               .string,   .required)
            .field(model.$data.key,              .data,     .required)
            //.field(model.$data.key,              .json,     .required)
            .field(model.$state.key,             .string,   .required)
            .field(model.$createdAt.path.first!, .datetime)
            .field(model.$updatedAt.path.first!, .datetime)
            .field(model.$deletedAt.path.first!, .datetime)
            .create()
            .flatMap {
                // Mysql could lock the entire table if there's no index on the field of the WHERE clause
                let sqlDb = database as! SQLDatabase
                return sqlDb.create(index: "i_\(JobModel.schema)_\(model.$state.key)")
                    .on(JobModel.schema)
                    .column("\(model.$state.key)")
                    .run()
            }
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobModel.schema).delete()
    }
}
