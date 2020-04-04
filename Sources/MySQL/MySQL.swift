import Foundation
import Fluent
import SQLKit
import FluentMySQLDriver
import QueuesFluentDriver

/*
struct dbDriver {
    private func dbDriver(_ database: Database) ->  MySQLDatabase {
        return database as! MySQLDatabase
    }
    
    private func encodeValue(_ value: String) -> MySQLData {
        return MySQLData(string: value)
    }
    
    func rawQuery(db: Database, query: SQLExpression) -> EventLoopFuture<UUID?> {
        let sql = (db as! SQLDatabase).serialize(query)
        let binds = sql.binds.map { encodeValue($0 as! String) }
        return dbDriver(db).query(sql.sql, binds).map { row in
            let id = row.first?.column(JobModel.init().$id.key.description)?.uuid
            return id
        }
    }
}

*/
