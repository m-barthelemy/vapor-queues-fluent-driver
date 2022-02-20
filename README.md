# QueuesFluentDriver

This Vapor Queues driver is an alternative to the (default) Redis driver, allowing you to use Fluent to store the Queues jobs into your relational database.


## Compatibility

This package makes use of some relatively recent, non standard SQL extensions added to some major database engines to support this exact use case: queuing systems, where there must be a guarantee that a task or job won't be picked by multiple workers.

This package should be compatible with:

- Postgres >= 11
- Mysql >= 8.0.1
- MariaDB >= 10.3

> Sqlite will only work if you have a custom, very low number of Queues workers (1-2), which makes it useless except for testing purposes

> Postgres: This package relies on some recently added features in `sql-kit` and `postgres-kit` >= 2.1.0. **Make sure you use a release of postgres-kit that is at least 2.1.0**

&nbsp;

## Usage



Add it to the  `Package.swift`  of your Vapor4 project: 

```swift

// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "app",
    platforms: [
        .macOS(.v10_15)
    ],
    ...
    dependencies: [
        ...
        .package(name: "QueuesFluentDriver", url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git", from: "2.0.0"),
        ...
    ],
    targets: [
        .target(name: "App", dependencies: [
            ...
            .product(name: "QueuesFluentDriver", package: "QueuesFluentDriver"),
            ...
        ]),
        ...
    ]
)

```

&nbsp;

This package needs a table, named `_jobs` by default, to store the Vapor Queues jobs. Add `JobModelMigrate` to your migrations:
```swift
// Ensure the table for storing jobs is created
app.migrations.add(JobModelMigrate())
```    

&nbsp;

Finally, load the `QueuesFluentDriver` driver:
```swift    
app.queues.use(.fluent())
```
Make sure you call `app.databases.use(...)` **before** calling `app.queues.use(.fluent())`!

&nbsp;

## Options

### Using a custom Database 
You can optionally create a dedicated Database, set to `isdefault: false` and with a custom `DatabaseID` and use it for your Queues.
In that case you would initialize the Queues configuration like this:

```swift
let queuesDb = DatabaseID(string: "my_queues_db")
app.databases.use(.postgres(configuration: dbConfig), as: queuesDb, isDefault: false)
app.queues.use(.fluent(queuesDb))
```

### Customizing the jobs table name
By default the `JobModelMigrate` migration will create a table named `_jobs`. You can customize the name during the migration :
```swift
app.migrations.add(JobModelMigrate(schema: "vapor_queues"))
```

### Listing jobs
If needed, you can list the jobs stored into the database:

```swift
import QueuesFluentDriver

let queue = req.queue as! FluentQueue

// Get the pending jobs
queue.list()

// Get the ones currently running
queue.list(state: .processing)

// Get the completed ones (only if you didn't set `useSoftDeletes` to `false`)
queue.list(state: .completed)

// For a custom Queue
queue.list(queue: "myCustomQueue")
```



&nbsp;


## Caveats


### Polling interval and number of workers
By default, the Vapor Queues package creates 2 workers per CPU core, and each worker would periodically poll the database for jobs to be run.
On a recent 4 cores MacBook, this means 8 workers querying the database every second by default.

You can change the jobs polling interval by calling:

```swift
app.queues.configuration.refreshInterval = .seconds(custom_value)
```

With Queues >=1.4.0, you can also configure the number of workers that will be started by setting `app.queues.configuration.workerCount`


### Soft Deletes
By default, this driver uses Fluent's "soft delete" feature, meaning that completed jobs stay in the database, but with a non-null `deleted_at` value.
If you want to delete the entry as soon as job is completed, you can set the `useSoftDeletes` option to `false`:

```swift
app.queues.use(.fluent(useSoftDeletes: false))
```

When using the default soft deletes option, it is probably a good idea to cleanup the completed jobs from time to time.
