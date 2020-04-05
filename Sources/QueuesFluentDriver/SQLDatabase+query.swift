import Foundation
import Fluent
import SQLKit

struct sqlCache{
    static var cache: [String: [Range<String.Index>]] = [:]
}

extension SQLDatabase {
    func query(db: SQLDatabase, sql: String, binds: [Encodable] = []) -> SQLRawBuilder {
        var sql = sql
        if(sqlCache.cache.keys.contains(sql)) {
            print("•••• Using SQL cache!")
        }
        else {
            sqlCache.cache[sql] = prepareSql(sql: sql, binds: binds).1
        }
        var bindPos = 0
        binds.forEach {
            bindPos += 1
            sql = sql.replacingOccurrences(of: "$\(bindPos)", with: "'\($0)'")
        }
        return db.raw(SQLQueryString(sql))
    }
    
    private func prepareSql(sql: String, binds: [Encodable]) -> (String, [Range<String.Index>]) {
        var bindIndices: [Range<String.Index>] = []
        var bindPos = 0
        binds.forEach { bind in
            bindPos += 1
            let bindIndex = sql.range(of: "$\(bindPos)")
            bindIndices.append(bindIndex!)
        }
        return (sql, bindIndices)
    }
    
    private func bindPrepared() {
        // sql.replacingCharacters(in: bindIndex!, with: "'\($0)'")
    }
}
