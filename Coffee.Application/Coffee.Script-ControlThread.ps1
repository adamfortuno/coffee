<#
	Copyright (C) 2018  Adam Fortuno

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU Affero General Public License as published
	by the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU Affero General Public License for more details.

	You should have received a copy of the GNU Affero General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>
Param (
    [Parameter(Mandatory=$true,Position=1)][string]$WorkloadLibraryFilePath
  , [Parameter(Mandatory=$true,Position=2)][string]$ThreadLibraryFilePath
  , [Parameter(Mandatory=$true,Position=3)][int64]$TaskCount
  , [Parameter(Mandatory=$true,Position=4)][string]$WorkloadType
  , [Parameter(Mandatory=$true,Position=5)][int]$Throttle
)

## Load the thread library
. $ThreadLibraryFilePath

$script_create_worker_thread = {
    Param (
        [Parameter(Mandatory=$true,Position=1)][string]$PathFunctionFile
      , [Parameter(Mandatory=$true,Position=2)][string]$WorkloadType
      , [Parameter(Mandatory=$true,Position=3)][string]$WorkloadID
    )
    
    if ( $error.count -gt 0 ) { $error.Clear() }
    
    . $PathFunctionFile

    Start-Sleep -Milliseconds 25

    $self_thread_id = [appdomain]::GetCurrentThreadId()
    
    if ( $WorkloadType -eq 'Write' ) {
        $scriptblock_workload = { Invoke-CoffeeWorkloadWrite }
    } elseif ( $WorkloadType -eq 'Update' ) {
        $scriptblock_workload = { Invoke-CoffeeWorkloadUpdate }
    } elseif ( $WorkloadType -eq 'Read' ) {
        $scriptblock_workload = { Invoke-CoffeeWorkloadRead }
    } else {
        throw 'Unknown type provided.'
    }

    $task_start_time = $(Get-Date -Format 'G')
    $task_duration = measure-command { & $scriptblock_workload }

    [pscustomobject]@{
        WorkloadID = $WorkloadID
        PathFunctionFile = $PathFunctionFile
        WorkloadType = $WorkloadType
        Thread = $self_thread_id
        ProcessID = $PID
        TimeStart = $task_start_time
        Duration = $task_duration.TotalMilliseconds
        ErrorCount = $error.count
        Errors = $error
    }
}

[object[]]$tasks_all = @()
[object[]]$tasks_complete = @()

$workload_id = $(New-Guid).Guid

$workload_parameters = @{
    'PathFunctionFile' = $WorkloadLibraryFilePath
    'WorkloadType' = $WorkLoadType
    'WorkloadID' = $workload_id
}

## Adding the SafeNet CNG Key Store Provider to the process.
## You do this once per process (not per thread).
$providers = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.Data.SqlClient.SqlColumnEncryptionKeyStoreProvider]"
$providers.Add("SFNT_CNG_STORE", $(New-Object 'System.Data.SqlClient.SqlColumnEncryptionCngProvider'));
[System.Data.SqlClient.SqlConnection]::RegisterColumnEncryptionKeyStoreProviders($providers)

$workload_start_time = $(Get-Date -Format 'G')
$workload_duration =  [system.diagnostics.stopwatch]::StartNew()

$tasks_all = Initialize-ThreadPool `
    -ScriptBlock $script_create_worker_thread `
    -Parameters $workload_parameters `
    -Occurrences $TaskCount `
    -Throttle $Throttle

$tasks_count = $tasks_all.count

if ($tasks_count -gt 0) {
    Write-Verbose "${tasks_count} tasks were returned"
    
    while ( $tasks_all.IsActive -contains $true ) {
        $tasks_active = $tasks_all | where-object { $_.IsActive -eq $True }

        foreach ( $task in $tasks_active ) {
            if ( $task.thread_handle.IsCompleted -eq 'Completed' ) {
                Write-Verbose 'Processing closed task'
                $tasks_complete += $task.session.EndInvoke($task.thread_handle)
                $task.session.Dispose()
                $task.IsActive = $False
            }
        }
    }
}

$workload_duration.Stop()
$workload_end_time = $(Get-Date -Format 'G')

$task_summary = [pscustomobject]@{
    'WorkloadID' = $workload_id
    'Workload' = $WorkloadType
    'TimeStart' = $workload_start_time
    'TimeEnd' = $workload_end_time
    'Timer' = $workload_duration
    'CountTasksRequested' = $TaskCount
    'WorkerThreads' = $Throttle
    'Hostname' = $env:computername
}

return $tasks_complete, $task_summary