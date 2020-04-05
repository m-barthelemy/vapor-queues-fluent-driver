import Foundation
import Queues
import Fluent
import SQLKit

struct FluentQueue {
    let db: Database?
    let context: QueueContext
    let useForUpdateSkipLocked: Bool
    let useSoftDeletes: Bool = true
}

extension FluentQueue: Queue {
    static let model = JobModel(id: UUID.generateRandom(), key: "", data: Data())
    
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
                let jobData = try JSONDecoder().decode(JobData.self, from: job.data)
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
        do {
            let data = try JSONEncoder().encode(jobStorage)
            return JobModel(id: uuid, key: key, data: data).save(on: database).map { return }
        }
        catch {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.jobDataEncodingError("Error encoding \(JobData.self): \(error)"))
        }
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
    
    /// Updates a Job state from `initial` to `pending` to signal that it is ready to be picked up for processing.
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        guard let uuid = UUID(uuidString: id.string) else {
            return database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        return database.query(JobModel.self)
            .filter(\.$id == uuid)
            .filter(\.$state == .initial)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                job.state = .pending
                return job.update(on: database)
        }
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        guard let database = db else {
            return self.context.eventLoop.makeFailedFuture(QueuesFluentError.databaseNotFound)
        }
        let db = database as! SQLDatabase
            
        var subQuery = db
            .select ()
            .column ("\(Self.model.$id.key)")
            .from   (JobModel.schema)
            .where  ("\(Self.model.$state.key)", SQLBinaryOperator.equal, JobState.pending)
            .orderBy("\(Self.model.$createdAt.path.first!)")
            .limit  (1)
        
        if (self.useForUpdateSkipLocked) {
            subQuery = subQuery.lockingClause(SQLForUpdateSkipLocked.forUpdateSkipLocked)
        }
        let subQueryGroup = SQLGroupExpression.init(subQuery.query)
        
        let query = db
            .update(JobModel.schema)
            .set("\(Self.model.$state.key)", to: JobState.processing)
            .set("\(Self.model.$updatedAt.path.first!)", to: Date())
            .where(
                SQLBinaryExpression(left: SQLColumn("\(Self.model.$id.key)"), op: SQLBinaryOperator.equal , right: subQueryGroup)
            )
            // Gross abuse
            .orWhere(SQLReturning.returningAll)
            .query
        
        let (sql, binds) = db.serialize(query)

        /*let driver = dbDriver()
        return driver.rawQuery(db: database, query: query).map { id in
            if(id != nil ) {
                return JobIdentifier(string: id!.uuidString)
            }
            else {
                return nil
            }
        }*/
        return db.query(db: db, sql: sql, binds: binds).first(decoding: UUID.self).optionalMap {
            return JobIdentifier(string: $0.uuidString)
        }
    }
    
}

enum QueuesFluentError: Error {
    case missingJob(_ id: JobIdentifier)
    case invalidIdentifier
    case jobDataEncodingError(_ message: String)
    case databaseNotFound
}
