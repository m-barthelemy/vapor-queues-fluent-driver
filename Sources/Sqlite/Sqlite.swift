import Foundation
import FluentSQLiteDriver
import QueuesFluentDriver

/*struct dbDriver {
    private func dbDriver(_ database: Database) -> SQLiteDatabase  {
        return database as! SQLiteDatabase
    }
    
    private func encodeValue(_ value: String) -> SQLiteData {
        return SQLiteData.text(value)
    }
    
    func rawQuery(db: Database, query: SQLExpression) -> EventLoopFuture<UUID?> {
        let sql = (db as! SQLDatabase).serialize(query)
        let binds = sql.binds.map { encodeValue($0 as! String) }
        return dbDriver(db).query(sql.sql, binds).map { row in
            let id = try? row.first?.decode(column: JobModel.init().$id.key.description, as: JobModel.IDValue.self)
            return id
        }
    }
}*/

