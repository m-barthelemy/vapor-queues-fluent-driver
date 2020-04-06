import Foundation
import SQLKit
import Fluent

protocol PopQueryProtocol {
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<UUID?>
}
