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
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        return database.query(JobModel.self)
            .filter(\.$id == uuid)
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
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        //let data = try! JSONEncoder().encode(jobStorage)
        return JobModel(id: uuid, key: key, data: jobStorage).save(on: database)
            //.map { return }
    }
    
    func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return database.query(JobModel.self)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                if(self.useSoftDeletes) {
                    job.state = .completed
                    job.deletedAt = Date()
                    return job.update(on: database)
                }
                else {
                    return job.delete(force: true, on: database)
                }
        }
    }
    
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        let sqlDb = database as! SQLDatabase
        return sqlDb
            .update (JobModel.schema)
            .set    (SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.pending))
            .where  (SQLColumn("\(FieldKey.id)"), .equal, SQLBind(uuid))
            .run()
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let db = database as! SQLDatabase
        
        var selectQuery = db
            .select ()
            .column ("\(FieldKey.id)")
            .from   (JobModel.schema)
            .where  ("\(FieldKey.state)", .equal, SQLBind(QueuesFluentJobState.pending))
            .orderBy("\(FieldKey.createdAt)")
            .limit  (1)
        if (self.dbType != .sqlite) {
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
            return JobIdentifier(string: id.uuidString)
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
            .where  ("\(FieldKey.state)", .equal, SQLBind(state))
        if(queue != nil) {
            query = query.where("\(FieldKey.key)", .equal, SQLBind(queue!))
        }
        if (self.dbType != .sqlite) {
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

public struct JobInfo: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var completedAt: Date?
}
