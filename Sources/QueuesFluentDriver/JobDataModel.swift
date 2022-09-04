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
final class JobDataModel: Fields {
    required init() {}
    
    /// The job data to be encoded.
    @Field(key: .payload)
    var payload: [UInt8]
    
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
    
    init(jobData: JobData) {
        self.payload = jobData.payload
        self.maxRetryCount = jobData.maxRetryCount
        self.attempts = jobData.attempts
        self.delayUntil = jobData.delayUntil
        self.jobName = jobData.jobName
        self.queuedAt = jobData.queuedAt
    }
}
