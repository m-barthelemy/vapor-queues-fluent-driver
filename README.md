# QueuesFluentDriver

**Note**: This package is still young. Please do open an issue if something doesn't work as expected. 



This Vapor Queues driver is an alternative to the (default) Redis driver, allowing you to use Fluent to store the Queues jobs into your relational database.


## Compatibility

This package makes use of some relatively recent, non standard SQL extensions added to some major database engines to support this exact use case: queuing systems, where there must be a guarantee that a task or job won't be picked by multiple workers.

This package should be compatible with:

- Postgres >= 9.5
- Mysql >= 8.0.1 (:rotating_light: requires mysql-nio >= 1.0.0-rc.1.2)
- MariaDB >= 10.3 (:rotating_light: requires mysql-nio >= 1.0.0-rc.1.2)


> Sqlite could be made to work in theory, but it would require that there is only one single Queues worker polling for jobs - and that the database has `journal_mode` set to `wal`. In short: it won't work, don't try.

&nbsp;

## Usage


Add it to the  `Package.swift`  of your Vapor4 project: 

```swift

// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "app",
    platforms: [
        .macOS(.v10_15)
    ],
    ...
    dependencies: [
        ...
        .package(url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git", from: "0.3.3"),
        ...
    ],
    targets: [
        .target(name: "App", dependencies: [
            ...
            "QueuesFluentDriver",
            ...
        ]),
        ...
    ]
)

```

&nbsp;

This package needs a table, named `jobs`, to store the Vapor Queues jobs. Add `JobModelMigrate` to your migrations:
```swift
// Ensure the table for storing jobs is created
app.migrations.add(JobModelMigrate())
```    
    
&nbsp;

Finally, load the `QueuesFluentDriver` driver:
```swift    
app.queues.use(.fluent())
```


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


### Polling interval
By default, the Vapor Queues package creates 2 workers per CPU core, and each worker would periodically poll the database for jobs to be run.
On a recent 4 cores MacBook, this means 8 workers querying the database every second by default.

You can change the jobs polling interval by calling:

```swift
app.queues.configuration.refreshInterval = TimeAmount.seconds(custom_value)
```


### Soft Deletes
By default, this driver uses Fluent's "soft delete" feature, meaning that completed jobs stay in the database, but with a non-null `deleted_at` value.
If you want to delete the entry as soon as job is completed, you can set the `useSoftDeletes` option to `false`:

```swift
app.queues.use(.fluent(useSoftDeletes: false))
```

When using the default soft deletes option, it is probably a good idea to cleanup the completed jobs from time to time.
