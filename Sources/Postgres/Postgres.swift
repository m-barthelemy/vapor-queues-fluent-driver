/*
import FluentPostgresDriver

struct dbDriver {
    private func dbDriver(_ database: Database) ->  PostgresDatabase {
        return database as! PostgresDatabase
    }
    
    
    func rawQuery(db: Database, query: SQLExpression) -> EventLoopFuture<UUID?> {
        let sql = (db as! SQLDatabase).serialize(query)
        let encoder = PostgresDataEncoder()
        let binds = sql.binds.map { try! encoder.encode($0) }
        
        return dbDriver(db).query(sql.sql, binds).map { row in
            let id = row.first?.column(JobModel.init().$id.key.description)?.uuid
            return id
        }
    }
}

*/
