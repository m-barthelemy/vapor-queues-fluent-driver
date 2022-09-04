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
    static var queue: Self { "queue" }
    static var data: Self { "data" }
    static var state: Self { "state" }

    static var runAt: Self { "run_at" }
    static var updatedAt: Self { "updated_at" }
    static var deletedAt: Self { "deleted_at" }
}

class JobModel: Model {
    public required init() {}
    
    public static var schema = "_jobs_meta"
    
    /// The unique Job ID
    @ID(custom: .id, generatedBy: .user)
    var id: String?
    
    /// The Job key
    @Field(key: .queue)
    var queue: String
    
    /// The current state of the Job
    @Field(key: .state)
    var state: QueuesFluentJobState
    
    /// Earliest date the job can run
    @OptionalField(key: .runAt)
    var runAtOrAfter: Date?
    
    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: .deletedAt, on: .delete)
    var deletedAt: Date?
    
    @Group(key: .data)
    var data: JobDataModel
    
    init(id: JobIdentifier, queue: String, jobData: JobDataModel) {
        self.id = id.string
        self.queue = queue
        self.state = .pending
        self.data = jobData
    }
}
