import Foundation
import Fluent
import SQLKit

public struct JobDataModelMigrate: Migration {
    public init() {}
    
    public init(schema: String) {
        JobDataModel.schema = schema
    }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobDataModel.schema)
            .id()
            .field(FieldKey.payload,        .data, .required)
            .field(FieldKey.maxRetryCount,  .int32, .required)
            .field(FieldKey.attempts,       .int32)
            .field(FieldKey.delayUntil,     .datetime)
            .field(FieldKey.queuedAt,       .datetime)
            .field(FieldKey.jobName,        .string, .required)
            .foreignKey(.id, references: JobModel.schema, .id, onDelete: .cascade)
            .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobModel.schema).delete()
    }
}
