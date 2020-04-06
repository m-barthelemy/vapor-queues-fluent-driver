import Foundation
import Queues
import Fluent
import SQLKit

struct FluentQueue {
    let db: Database?
    let context: QueueContext
    let dbType: QueuesFluentDbType
    let useSoftDeletes: Bool = true
}

extension FluentQueue: Queue {
    static let model = JobModel(id: UUID.generateRandom(), key: "")
    
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
                let jobData = job.data//try JSONDecoder().decode(JobData.self, from: job.data)
                return jobData!
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
            let data = jobStorage //try JSONEncoder().encode(jobStorage)
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
            
        var selectQuery = db
            .select ()
            .column ("\(Self.model.$id.key)")
            .from   (JobModel.schema)
            //.where  ("\(Self.model.$state.key)", SQLBinaryOperator.equal, JobState.pending)
            .where("\(Self.model.$state.key)", SQLBinaryOperator.equal, SQLBind.init(JobState.pending))
            .orderBy("\(Self.model.$createdAt.path.first!)")
            .limit  (1)
        
        if (self.dbType != .sqlite) {
            selectQuery = selectQuery.lockingClause(SQLForUpdateSkipLocked.forUpdateSkipLocked)
        }
        let subQueryGroup = SQLGroupExpression.init(selectQuery.query)
        
        let query = db
            .update(JobModel.schema)
            //.set("\(Self.model.$state.key)", to: JobState.processing)
            .set(SQLColumn.init("\(Self.model.$state.key)"), to: SQLBind.init(JobState.processing))
            //.set("\(Self.model.$updatedAt.path.first!)", to: Date())
            .set(SQLColumn.init("\(Self.model.$updatedAt.path.first!)"), to: SQLBind.init(Date()))
            .where(
                SQLBinaryExpression(left: SQLColumn("\(Self.model.$id.key)"), op: SQLBinaryOperator.equal , right: subQueryGroup)
            )
            // Gross abuse
            .orWhere(SQLReturning.returning(column: Self.model.$id.key))
            .query
        
        
        db.execute(sql: query) { (row) in
            print("••• columns: \(row.allColumns)")
            let id = try? row.decode(column: "\(Self.model.$id.key)", as: UUID.self)
            print("••• returned id \(id)")
        }
        // UPDATE `jobs`
        // SET `state` = ?, `updated_at` = ?
        // WHERE `id` = (SELECT `id` FROM `jobs` WHERE `state` = ? ORDER BY `created_at` ASC LIMIT 1 FOR UPDATE SKIP LOCKED)
        // OR 1=2
        // RETURNING "id"
        
        // -- should be --
        
        // BEGIN TRANSACTION
        // SELECT `id` FROM `jobs` WHERE `state` = ? ORDER BY `created_at` ASC LIMIT 1 FOR UPDATE SKIP LOCKED;
        // UPDATE `jobs`
        // SET
        //   `state` = ?,
        //   `updated_at` = ?
        // WHERE `id` = xxxxxxx;
        // COMMIT
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
        return db.query(db: db, sql: sql, binds: binds).first().optionalMap { row in
            return JobIdentifier(string: (try! row.decode(column: "\(Self.model.$id.key)", as: UUID.self)).uuidString)
        }
    }
    
}
