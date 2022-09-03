# QueuesFluentDriver

This Vapor Queues driver stores the Queues jobs metadata into a relational database. It is an alternative to the default Redis driver.


## Compatibility

This package makes use of some relatively recent, non standard SQL extensions added to some major database engines to support this exact use case: queuing systems, where there must be a guarantee that a task or job won't be picked by multiple workers.

This package should be compatible with:

- Postgres >= 11
- Mysql >= 8.0.1
- MariaDB >= 10.3

> Sqlite will only work if you have a custom, very low number of Queues workers (1-2), which makes it useless except for testing purposes

&nbsp;

## Usage



Add it to the  `Package.swift`  of your Vapor4 project: 

```swift

// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "app",
    platforms: [
        .macOS(.v10_15)
    ],
    ...
    dependencies: [
        ...
        .package(name: "QueuesFluentDriver", url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git", from: "2.0.0-beta1"),
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

This package needs a table, named `_jobs_meta` by default, to store the Vapor Queues jobs. Make sure to add this to your migrations:
```swift
// Ensure the table for storing jobs is created
app.migrations.add(JobMetadataMigrate())
```    

&nbsp;

Finally, load the `QueuesFluentDriver` driver:
```swift    
app.queues.use(.fluent())
```

⚠️ Make sure you call `app.databases.use(...)` **before** calling `app.queues.use(.fluent())`!

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
You can customize the name of the table used by this driver during the migration :
```swift
app.migrations.add(JobMetadataMigrate(schema: "my_jobs"))
```

### Soft Deletes
By default, completed jobs are deleted from the two database tables used by this driver.
If you want to keep them, you can use Fluent's "soft delete" feature, which just sets the `deleted_at` field to a non-null value and excludes rows from queries by default:

```swift
app.queues.use(.fluent(useSoftDeletes: true))
```

When enabling this option, it is probably a good idea to cleanup the completed jobs from time to time.

&nbsp;


## Caveats


### Polling interval and number of workers
By default, the Vapor Queues package creates 2 workers per CPU core, and each worker would poll the database for jobs to be run every second.
On a 4 cores system, this means 8 workers querying the database every second by default.

You can change the jobs polling interval by calling:

```swift
app.queues.configuration.refreshInterval = .seconds(custom_value)
```

With Queues >=1.4.0, you can also configure the number of workers that will be started by setting `app.queues.configuration.workerCount`

