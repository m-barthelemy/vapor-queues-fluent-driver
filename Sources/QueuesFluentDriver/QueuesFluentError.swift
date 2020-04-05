import Queues

enum QueuesFluentError: Error {
    case missingJob(_ id: JobIdentifier)
    case invalidIdentifier
    case jobDataEncodingError(_ message: String)
    case databaseNotFound
}
