//
//  File.swift
//  
//
//  Created by Matthieu.Barthélemy on 4/5/20.
//

import Foundation
import Fluent
import SQLKit


extension SQLDatabase {
    func query(db: SQLDatabase, sql: String, binds: [Encodable] = []) -> SQLRawBuilder {
        var sql = sql
        var bindPos = 0
        binds.forEach {
            bindPos += 1
            sql = sql.replacingOccurrences(of: "$\(bindPos)", with: "'\($0)'")
        }
        return db.raw(SQLQueryString(sql))
    }
}
