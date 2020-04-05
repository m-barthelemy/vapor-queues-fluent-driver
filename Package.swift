// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QueuesFluentDriver",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "QueuesFluentDriver",
            targets: ["QueuesFluentDriver"]),
        /*.library(
            name: "QueuesPostgresDriver",
            targets: ["QueuesPostgresDriver"]),*/
        /*.library(
            name: "QueuesSqliteDriver",
            targets: ["QueuesSqliteDriver"]),*/
        /*.library(
            name: "QueuesMySQLDriver",
            targets: ["QueuesMySQLDriver"])*/
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc"),
        //.package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0-rc"),
        //.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.0.0-rc"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0-rc.1.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "QueuesFluentDriver",
            dependencies: [
                "Fluent",
                "SQLKit",
                "FluentPostgresDriver",
                //"FluentMySQLDriver",
                //"FluentSQLiteDriver",
                "Queues"
            ],
            path: "Sources"
        ),
        /*.target(
            name: "QueuesPostgresDriver",
            dependencies: [
                "Fluent",
                "FluentPostgresDriver",
                "SQLKit",
                "Queues",
            ],
            path: "Sources",
            exclude: ["MySQL"]
        ),
        .target(
            name: "QueuesMySQLDriver",
            dependencies: [
                "Fluent",
                "FluentMySQLDriver",
                "SQLKit",
                "Queues"
            ],
            path: "Sources",
            exclude: ["Postgres"]
        )*/
        /*.target(
            name: "QueuesSqliteDriver",
            dependencies: [
                "Fluent",
                "FluentSQLiteDriver",
                "SQLKit",
                "Queues",
                "QueuesFluentDriver"
            ],
            path: "Sources"
        ),
        */
        /*.testTarget(
            name: "QueuesFluentDriverTests",
            dependencies: ["QueuesFluentDriver"]),*/
    ]
)
