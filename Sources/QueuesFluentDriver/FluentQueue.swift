import Foundation
import Queues
import Fluent
import SQLKit

public struct FluentQueue {
    public let context: QueueContext
    let db: Database
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
}

extension FluentQueue: Queue {
    public func get(_ id: JobIdentifier) -> EventLoopFuture<JobData> {
        return db.query(JobDataModel.self)
            .filter(\.$id == id.string)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMapThrowing { job in
                return JobData(
                    payload: Array(job.payload),
                    maxRetryCount: job.maxRetryCount,
                    jobName: job.jobName,
                    delayUntil: job.delayUntil,
                    queuedAt: job.queuedAt,
                    attempts: job.attempts ?? 0
                )
            }
    }
    
    public func set(_ id: JobIdentifier, to jobStorage: JobData) -> EventLoopFuture<Void> {
        let jobModel = JobModel(id: id, queue: queueName.string)
        // If the job must run at a later time, ensure it won't be picked earlier since
        // we sort pending jobs by creation date when querying
        jobModel.runAtOrAfter = jobStorage.delayUntil ?? Date()
        
        let jobData = JobDataModel(id: id, jobData: jobStorage)
        
        return jobModel.save(on: db).flatMap { metadata in
            return jobData.save(on: db).map{ nothing in
                return
            }
        }
    }
    
    public func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return db.query(JobModel.self)
            .filter(\.$id == id.string)
            .filter(\.$state != .completed)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                if self.useSoftDeletes {
                    job.state = .completed
                    job.deletedAt = Date()
                    return job.update(on: self.db)
                } else {
                    return job.delete(force: true, on: self.db)
                }
        }
    }
    
    public func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let sqlDb = db as? SQLDatabase else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        return sqlDb
            .update(JobModel.schema)
            .set(SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.pending))
            .where(SQLColumn("\(FieldKey.id)"), .equal, SQLBind(id.string))
            .run()
    }
    
    /// Currently selects the oldest job pending execution
    public func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let sqlDb = db as? SQLDatabase else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        
        var selectQuery = sqlDb
            .select()
            .column("\(FieldKey.id)")
            .from(JobModel.schema)
            .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
            .where(SQLColumn("\(FieldKey.queue)"), .equal, SQLBind(self.queueName.string))
            .where(SQLColumn("\(FieldKey.runAt)"), .lessThanOrEqual, SQLBind(Date()))
            .orderBy("\(FieldKey.runAt)")
            .limit(1)
        if self.dbType != .sqlite {
            selectQuery = selectQuery.lockingClause(SQLSkipLocked.forUpdateSkipLocked)
        }
        
        var popProvider: PopQueryProtocol!
        switch (self.dbType) {
            case .postgresql:
                popProvider = PostgresPop()
            case .mysql:
                popProvider = MySQLPop()
            case .sqlite:
                popProvider = SqlitePop()
            default:
                return db.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        return popProvider.pop(db: db, select: selectQuery.query).optionalMap { id in
            return JobIdentifier(string: id)
        }
    }
}
