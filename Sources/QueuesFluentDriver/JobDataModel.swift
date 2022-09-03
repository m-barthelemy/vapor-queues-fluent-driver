import Foundation
import Fluent
import Queues

extension FieldKey {
    static var payload: Self { "payload" }
    static var maxRetryCount: Self { "max_retries" }
    static var attempts: Self { "attempt" }
    static var delayUntil: Self { "delay_until" }
    static var queuedAt: Self { "queued_at" }
    static var jobName: Self { "job_name" }
}

/// Handles storage of a `JobData` into the database
class JobDataModel: Model {
    required init() {}
    
    public static var schema = "_jobs_data"
    
    /// The unique Job uuid
    /// Since we have a 1-1 relationship with the `JobModel` parent, this is also the ID of the parent
    @ID(custom: .id, generatedBy: .user)
    var id: String?
    
    /// The job data to be encoded.
    @Field(key: .payload)
    var payload: Data
    
    /// The maxRetryCount for the `Job`.
    @Field(key: .maxRetryCount)
    var maxRetryCount: Int
    
    /// The number of attempts made to run the `Job`.
    @Field(key: .attempts)
    var attempts: Int?
    
    /// A date to execute this job after
    @OptionalField(key: .delayUntil)
    var delayUntil: Date?
    
    /// The date this job was queued
    @Field(key: .queuedAt)
    var queuedAt: Date
    
    /// The name of the `Job`
    @Field(key: .jobName)
    var jobName: String
    
    @Parent(key: .id)
    var medatata: JobModel
    
    init(id: JobIdentifier, jobData: JobData) {
        self.id = id.string
        self.payload = Data(jobData.payload)
        self.maxRetryCount = jobData.maxRetryCount
        self.attempts = jobData.attempts
        self.delayUntil = jobData.delayUntil
        self.jobName = jobData.jobName
        self.queuedAt = jobData.queuedAt
    }
}
