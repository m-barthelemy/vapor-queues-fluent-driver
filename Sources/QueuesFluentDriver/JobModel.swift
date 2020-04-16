import Foundation
import Fluent
import Queues

public enum QueuesFluentJobState: String, Codable, CaseIterable {
    /// Ready to be oicked up for execution
    case pending
    case processing
    /// Executed, regardless if it was successful or not
    case completed
}

extension FieldKey {
    static var key: Self { "key" }
    static var data: Self { "data" }
    static var state: Self { "state" }

    static var createdAt: Self { "created_at" }
    static var updatedAt: Self { "updated_at" }
    static var deletedAt: Self { "deleted_at" }
}

class JobModel: Model {
    public required init() {}
    
    /// Properties
    public static var schema = "jobs"
    
    /// The unique Job uuid
    @ID(key: .id)
    var id: UUID?
    
    /// The Job key
    @Field(key: .key)
    var key: String
    
    /// The Job data
    @Field(key: .data)
    //var data: JobData?
    var data: Data
    
    /// The current state of the Job
    @Field(key: .state)
    var state: QueuesFluentJobState
    
    /// The created timestamp
    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?
    
    /// The updated timestamp
    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: .deletedAt, on: .delete)
    var deletedAt: Date?
    
    
    init(id: UUID, key: String, data: JobData) {
        self.id = id
        self.key = key
        self.data = try! JSONEncoder().encode(data)
        self.state = .pending
    }
}
