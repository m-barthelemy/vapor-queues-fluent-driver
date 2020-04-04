/*
import FluentMySQLDriver
import QueuesFluentDriver

#if canImport(FluentMySQLDriver)
struct dbDriver {
    func db(_ database: Database) ->  MySQLDatabase {
        return database as! MySQLDatabase
    }
    func encodeValue(_ value: String) -> MySQLData {
        return MySQLData(string: value)
    }
}
#endif
*/
