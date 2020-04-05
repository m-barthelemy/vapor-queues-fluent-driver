import Foundation
import FluentSQLiteDriver
import QueuesFluentDriver

/*struct dbDriver {
    private func dbDriver(_ database: Database) -> SQLiteDatabase  {
        return database as! SQLiteDatabase
    }
    
    func rawQuery(db: Database, query: SQLExpression) -> EventLoopFuture<UUID?> {
        let sql = (db as! SQLDatabase).serialize(query)
        let encoder = SQLiteDataEncoder()
        let binds = sql.binds.map { try! encoder.encode($0) }
        return dbDriver(db).query(sql.sql, binds).map { row in
            let id = try? row.first?.decode(column: JobModel.init().$id.key.description, as: JobModel.IDValue.self)
            return id
        }
    }
}*/

