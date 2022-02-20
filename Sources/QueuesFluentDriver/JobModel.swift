import Foundation
import Fluent
import Queues

public enum QueuesFluentJobState: String, Codable, CaseIterable {
    /// Ready to be picked up for execution
    case pending
    case processing
    /// Executed, regardless if it was successful or not
    case completed
}

extension FieldKey {
    static var jobId: Self { "job_id" }
    static var queue: Self { "queue" }
    static var data: Self { "data" }
    static var state: Self { "state" }

    static var createdAt: Self { "created_at" }
    static var updatedAt: Self { "updated_at" }
    static var deletedAt: Self { "deleted_at" }
}

class JobModel: Model {
    public required init() {}
    
    public static var schema = "_jobs"
    
    /// The unique Job uuid
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: .jobId)
    var jobId: String?
    
    /// The Job key
    @Field(key: .queue)
    var queue: String
    
    /// The Job data
    @Field(key: .data)
    var data: JobData
    
    /// The current state of the Job
    @Field(key: .state)
    var state: QueuesFluentJobState
    
    /// Creation date by default; `delayUntil` if it's a delayed job
    @OptionalField(key: .createdAt)
    var createdAt: Date?
    
    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: .deletedAt, on: .delete)
    var deletedAt: Date?
    
    
    init(jobId: String, queue: String, data: JobData) throws {
        self.jobId = jobId
        self.queue = queue
        self.data = data
        self.state = .pending
    }
}
