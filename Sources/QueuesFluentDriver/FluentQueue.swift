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
        return db.query(JobModel.self)
            .filter(\.$jobId == id.string)
            .filter(\.$state != .pending)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMapThrowing { job in
                return try JSONDecoder().decode(JobData.self, from: job.data)
            }
    }
    
    public func set(_ id: JobIdentifier, to jobStorage: JobData) -> EventLoopFuture<Void> {
        do {
            let jobModel = try JobModel(jobId: id.string, queue: queueName.string, data: jobStorage)
            return jobModel.save(on: db)
        }
        catch {
            return db.eventLoop.makeFailedFuture(QueuesFluentError.jobDataEncodingError(error.localizedDescription))
        }        
    }
    
    public func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return db.query(JobModel.self)
            .filter(\.$jobId == id.string)
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
            .where(SQLColumn("\(FieldKey.jobId)"), .equal, SQLBind(id.string))
            .run()
    }
    
    /// Currently selects the oldest job pending execution
    public func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let sqlDb = db as? SQLDatabase else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        
        var selectQuery = sqlDb
            .select()
            .column("\(FieldKey.jobId)")
            .from(JobModel.schema)
            .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
            .where(SQLColumn("\(FieldKey.queue)"), .equal, SQLBind(self.queueName.string))
            .orderBy("\(FieldKey.createdAt)")
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
    
    /// /!\ This is a non standard extension.
    public func list(queue: String? = nil, state: QueuesFluentJobState = .pending) -> EventLoopFuture<[JobData]> {
        guard let sqlDb = db as? SQLDatabase else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        var query = sqlDb
            .select()
            .column("*")
            .from(JobModel.schema)
            .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(state))
        if let queue = queue {
            query = query.where(SQLColumn("\(FieldKey.queue)"), .equal, SQLBind(queue))
        }
        if self.dbType != .sqlite {
            query = query.lockingClause(SQLSkipLocked.forShareSkipLocked)
        }
        query = query.limit(1000)
        
        var jobs = [JobData]()
        return sqlDb.execute(sql: query.query) { (row) -> Void in
            do {
                let job = try row.decode(column: "\(FieldKey.data)", as: Data.self)
                let jobData = try JSONDecoder().decode(JobData.self, from: job)
                jobs.append(jobData)
            }
            catch {
                return self.db.eventLoop.makeFailedFuture(QueuesFluentError.jobDataDecodingError("\(error)"))
                    .whenSuccess {$0}
            }
        }
        .map {
            return jobs
        }
    }
}
