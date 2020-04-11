import Foundation
import Queues
import Fluent
import SQLKit

struct FluentQueue {
    let db: Database?
    let context: QueueContext
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool
    static let model = JobModel(id: UUID.generateRandom(), key: "")
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
            .set    (SQLColumn("\(FluentQueue.model.$state.key)"), to: SQLBind(QueuesFluentJobState.pending))
            .where  (SQLColumn("\(FluentQueue.model.$id.key)"), .equal, SQLBind(uuid))
            .run()
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let db = database as! SQLDatabase
        
        var selectQuery = db
            .select ()
            .column ("\(Self.model.$id.key)")
            .from   (JobModel.schema)
            .where  ("\(Self.model.$state.key)", .equal, SQLBind(QueuesFluentJobState.pending))
            .orderBy("\(Self.model.$createdAt.path.first!)")
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
            @unknown default:
                return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
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
            .where  ("\(Self.model.$state.key)", .equal, SQLBind(state))
        if(queue != nil) {
            query = query.where("\(Self.model.$key.key)", .equal, SQLBind(queue!))
        }
        if (self.dbType != .sqlite) {
            query = query.lockingClause(SQLSkipLocked.forShareSkipLocked)
        }
        var pendingJobs = [JobData]()
        return db.execute(sql: query.query) { (row) -> Void in
            do {
                let jobData = try row.decode(column: "\(FluentQueue.model.$data.key)", as: JobData.self)
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
