import Foundation
import Fluent
import Queues

enum JobState: String, Codable, CaseIterable {
    /// Ready to be oicked up for execution
    case pending
    case processing
    /// Executed, regardless if it was successful or not
    case completed
}

class JobModel: Model {
    public required init() {}
    
    /// Properties
    public static var schema = "jobs"
    
    /// The unique Job uuid
    @ID(key: .id)
    var id: UUID?
    
    /// The Job key
    @Field(key: "key")
    var key: String
    
    /// The Job data
    @Field(key: "data")
    //var data: JobData?
    var data: Data
    
    /// The current state of the Job
    @Field(key: "state")
    var state: JobState
    
    /// The created timestamp
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// The updated timestamp
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    
    init(id: UUID, key: String, data: JobData? = nil) {
        self.id = id
        self.key = key
        self.data = try! JSONEncoder().encode(data)
        self.state = .pending
    }
}
