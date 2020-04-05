import Foundation
import Queues
import Fluent
import SQLKit

struct FluentQueue {
    let database: Database
    let context: QueueContext
    let useForUpdateSkipLocked: Bool
    let useSoftDeletes: Bool = true
}

extension FluentQueue: Queue {
    static let model = JobModel(id: UUID.generateRandom(), key: "", data: Data())
    
    func get(_ id: JobIdentifier) -> EventLoopFuture<JobData> {
        guard let uuid = UUID(uuidString: id.string) else {
            return self.database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        return self.database.query(JobModel.self)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMapThrowing { job in
                let jobData = try JSONDecoder().decode(JobData.self, from: job.data)
                return jobData
        }
    }
    
    func set(_ id: JobIdentifier, to jobStorage: JobData) -> EventLoopFuture<Void> {
        guard let uuid = UUID(uuidString: id.string) else {
            return self.database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        do {
            let data = try JSONEncoder().encode(jobStorage)
            return JobModel(id: uuid, key: key, data: data).save(on: database).map { return }
        }
        catch {
            return self.database.eventLoop.makeFailedFuture(QueuesFluentError.jobDataEncodingError("Error encoding \(JobData.self): \(error)"))
        }
    }
    
    func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let uuid = UUID(uuidString: id.string) else {
            return self.database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        // This does the equivalent of a Fluent Softdelete but sets the `state` to `completed`
        return self.database.query(JobModel.self)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                if(self.useSoftDeletes) {
                    job.state = .completed
                    job.deletedAt = Date()
                    return job.update(on: self.database)
                }
                else {
                    return job.delete(force: true, on: self.database)
                }
        }
    }
    
    /// Updates a Job state from `initial` to `pending` to signal that it is ready to be picked up for processing.
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        guard let uuid = UUID(uuidString: id.string) else {
            return self.database.eventLoop.makeFailedFuture(QueuesFluentError.invalidIdentifier)
        }
        return self.database.query(JobModel.self)
            .filter(\.$id == uuid)
            .filter(\.$state == .initial)
            .first()
            .unwrap(or: QueuesFluentError.missingJob(id))
            .flatMap { job in
                job.state = .pending
                return job.update(on: self.database)
        }
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        self.database.withConnection { conn in
            let db = conn as! SQLDatabase
            
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
            
            let driver = dbDriver()
            return driver.rawQuery(db: self.database, query: query).map { id in
                if(id != nil ) {
                    return JobIdentifier(string: id!.uuidString)
                }
                else {
                    return nil
                }
            }
        }
    }
    
}

enum QueuesFluentError: Error {
    case missingJob(_ id: JobIdentifier)
    case invalidIdentifier
    case jobDataEncodingError(_ message: String)
}
