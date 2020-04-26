import Foundation
import Queues
import Fluent
import SQLKit

struct FluentQueue {
    let db: Database?
    let context: QueueContext
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
}

extension FluentQueue: Queue {
    func get(_ id: JobIdentifier) -> EventLoopFuture<JobData> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        return database.query(JobModel.self)
            .filter(\.$jobId == id.string)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMapThrowing { job in
                let jobData = try! JSONDecoder().decode(JobData.self, from: job.data)
                return jobData
        }
    }
    
    func set(_ id: JobIdentifier, to jobStorage: JobData) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        //let data = try! JSONEncoder().encode(jobStorage)
        return JobModel(jobId: id.string, queue: queueName.string, data: jobStorage)
            .save(on: database)
    }
    
    func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return database.query(JobModel.self)
            .filter(\.$jobId == id.string)
            .filter(\.$state != QueuesFluentJobState.completed)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                if self.useSoftDeletes {
                    job.state = .completed
                    job.deletedAt = Date()
                    return job.update(on: database)
                } else {
                    return job.delete(force: true, on: database)
                }
        }
    }
    
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let sqlDb = database as! SQLDatabase
        return sqlDb
            .update(JobModel.schema)
            .set   (SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.pending))
            .where (SQLColumn("\(FieldKey.jobId)"), .equal, SQLBind(id.string))
            .run()
    }
    
    /// Currently selects the oldest job pending execution
    func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let db = database as! SQLDatabase
        
        var selectQuery = db
            .select ()
            .column ("\(FieldKey.jobId)")
            .from   (JobModel.schema)
            .where  (SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
            .where  (SQLColumn("\(FieldKey.queue)"), .equal, SQLBind(self.queueName.string))
            .orderBy("\(FieldKey.createdAt)")
            .limit  (1)
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
        }
        return popProvider.pop(db: database, select: selectQuery.query).optionalMap { id in
            return JobIdentifier(string: id)
        }
    }
    
    /// /!\ This is a non standard extension.
    public func list(queue: String? = nil, state: QueuesFluentJobState = .pending) -> EventLoopFuture<[JobData]> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let db = database as! SQLDatabase
        var query = db
            .select()
            .from   (JobModel.schema)
            .where  (SQLColumn("\(FieldKey.state)"), .equal, SQLBind(state))
        if let queue = queue {
            query = query.where(SQLColumn("\(FieldKey.queue)"), .equal, SQLBind(queue))
        }
        if self.dbType != .sqlite {
            query = query.lockingClause(SQLSkipLocked.forShareSkipLocked)
        }
        var pendingJobs = [JobData]()
        return db.execute(sql: query.query) { (row) -> Void in
            do {
                let jobData = try row.decode(column: "\(FieldKey.data)", as: JobData.self)
                pendingJobs.append(jobData)
            }
            catch {
                self.context.eventLoop.makeFailedFuture(QueuesFluentError.jobDataDecodingError("\(error)")).whenSuccess {$0}
            }
        }
        .map {
            return pendingJobs
        }
    }
}
