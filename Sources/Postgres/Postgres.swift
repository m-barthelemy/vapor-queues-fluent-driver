
import FluentPostgresDriver

#if canImport(FluentPostgresDriver)
struct dbDriver {
    func dbDriver(_ database: Database) ->  PostgresDatabase {
        return database as! PostgresDatabase
    }
    
    func encodeValue(_ value: String) -> PostgresData {
        return PostgresData(string: value)
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
#endif


