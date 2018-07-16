# coffee

## Summary

Coffee is simulated point-of-sale application. It was built to test the effect of SQL Server feature and configuration changes on traditional online transaction processing (OLTP) workloads.

## Architecture

Coffee is predominately written in Powershell. The application is commandline based meaning there is no user interface. The application is composed of several scripts:

* *Coffee.Analyze.ps1*, this script contains functions to summarize test results. These functions are used by the test operator.
* *run.ps1*, this is the application's bootstrapper. It launches a Coffee session.
* *Coffee.Application.ps1*, contains functions that write, read, and update the coffee database.
* *Coffee.Application.ps1.config*, configurable characteristics of Coffee. Most notibly the connection string for the Coffee database(s).
* *Coffee.Thread.ps1*, contains functions that create and manage threads.
* *Coffee.Script-ControlThread.ps1*, hosts the script block run by the control thread.

The scripts have the following dependencies: 

![Coffee System Architecture](/documentation/documentation_system_architecture.png?raw=true "System Architecture")

Scripts are loaded through [dot-sourcing](https://blogs.technet.microsoft.com/heyscriptingguy/2010/08/10/how-to-reuse-windows-powershell-functions-in-scripts/).

Coffee's scripts wraps several SQL Server databases. The application inserts, updates, deletes, and retrieves data from these databases. We use different databases to exercise different SQL Server features. Presently, there is one database with no features enabled; baseline database. While a second, seperate database, uses Always Encrypted. While databases may implement different features, they use the same/similar schema. This lets us compare like workloads to determine whether a given feature adversely impacts performance.

The following diagram shows Coffee database's schema:

![Coffee Relational Model](/documentation/documentation_schema_diagram.png?raw=true "Relational Model")

The application employs threading to push a workload to a given database. The bootstrapper creates a control thread, which creates one or more worker threads. There is one control thread per workload. There are one or more worker threads per workload. The number of workers is specified by the `Throttle` parameter in the `run.ps1` script.  Worker threads execute a given task, such as a specific insert or update. Once a thread has completed its task, it gets another task from the workload's work queue. Tasks are distributed across the worker threads in a FIFO manor.

When a workload has completed (all tasks have been executed), the calling process is given an task collection with information on each task including execution time and any errors the task generated.

## Dependencies

Coffee works with all editions of SQL Server and supports the following versions:

* SQL Server 2014 (12.x)
* SQL Server 2016 (13.x)
* SQL Server 2017 (14.x)

Coffee requires the following:

* Powershell 5.0 or greater

## Installation Instructions

### Instructions

There is no installer for this project. Operators need to install the system manually.

To run these scripts, you'll need Powershell 5.x. Powershell 5.x ships with Windows 10 and Windows Server 2016. If you're running Windows Server 2012 R2, you'll need to apply an upgrade (KB3191564) to your host. The update for Windows 8 and Windows 2012 R2 has been included in this repository. In the [installers](Coffee.Application\installers) folder.

Throughout these instructions you'll see references to "Coffee database". The Coffee application comes with a few databases. These are the databases you'll be running load against. Presently, there are two databases. One is for testing Always Encrypted. One is for baseline testing.

1. Deploy encrypted Coffee database.
1. Deploy un-encrypted Coffee database.
1. Create a host folder for the application on your application server; recommend `c:\temp`.
1. Copy the `key` folder to the application directory.
1. Copy the `Coffee.Application` folder to the application directory.
1. If not done already, login to the application server.
1. Open a new Powershell session as an Administrator (Run as Administrator).
1. In Powershell, navigate to the `key` folder in the application directory.
1. Run the `AlwaysEncrypted.import.ps1` script.
1. Grant yourself read permission to the certificate you just imported's private key.
    1. Right-click the Windows menu and select `Run`.
    1. Type `mmc`. If you receive a UAC prompt, select `Yes`.
    1. Select `Add/Remove Snap-in...` from the `File` menu.
    1. Add the `Certificates` snap-in.
    1. Select `Computer account` certificates to managed prompt.
    1. Select `Local Computer` when asked what machine to access.
    1. Click `Ok`.
    1. Find the `Always Encrypted Certificate` certificate in the `\Certificates\Personal\Certificates\` folder.
    1. Right-click the certificate, select `All Tasks`, and `Manage Private Keys...`
    1. Grant the user that will be executing the tests `Read` permissions.
1. Update Coffee database connection string in the [application configuration file](.\Coffee.Application\Coffee.Application.ps1.config) to point to the coffee database you would like to test with 

## Usage Instructions

The `run.ps1` script initiates a workload test.

```Powershell
$workload_write, $stop_watch = .\run.ps1 -TaskCount 12500 `
    -WorkLoadType Write `
    -Throttle 3 `
    -Verbose
```

Get the status of a given thread.

```Powershell
. .\Coffee.Thread.ps1

Get-ThreadStatus -Thread $workload_write
```

Displays statistics about a completed workload.

```Powershell
. .\Coffee.Analyze.ps1

Show-CoffeeWorkloadStats -CompletedTasks $workload_write -StopWatch $stop_watch
```

```
errors_count            : @{Name=0}
threads_count           : 3
tasks_count             : 12500
execution_time_avg      : 65.7824956800004
execution_time_max      : 3019.5501
execution_time_min      : 5.8695
threads_tasks_procedded : {@{Name=1524; Count=1892}, @{Name=7452; Count=5336}, @{Name=6216; Count=5272}}
execution_time_total    : 1135125
```

## Monitoring Guidance

There are two text files in the etc directory (coffee\Coffee.Application\etc). These files list performance counters.

* performance_counters_appserver.txt, performance counters for the application server.
* performance_counters_dbserver.txt, performance counters for the database server.