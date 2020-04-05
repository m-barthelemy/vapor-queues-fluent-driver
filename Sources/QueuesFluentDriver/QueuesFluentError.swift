import Queues

enum QueuesFluentError: Error {
    /// Couldn't find a job with this Id
    case missingJob(_ id: JobIdentifier)
    /// The JobIdentifier is not a valid UUID
    case invalidIdentifier
    /// Error encoding the jon Payload to JSON
    case jobDataEncodingError(_ message: String)
    /// The given DatabaseID doesn't match any existing database configured in the Vapor app.
    case databaseNotFound
}
