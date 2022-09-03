import Foundation
import Fluent

public struct JobDataMigrate: Migration {
    public init() {}
    
    public init(schema: String) {
        JobDataModel.schema = schema
    }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobDataModel.schema)
            .field(.id,                     .string, .identifier(auto: false))
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
        return database.schema(JobDataModel.schema).delete()
    }
}
