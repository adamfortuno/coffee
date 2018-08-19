<#
    .Synopsis
    Coffee Driver Script

    .Description
    This script executes a specified workload against the Coffee
    application.

    .Parameter TaskCount
    The number of orders (tasks) to be processed. For example, if
    you specify a TaskCount of 100 and WorkloadType of write, 100
    new orders will be created.
    
    .Parameter WorkLoadType
    The type of workload being run: write, update, or read. The write
    workload will create new orders. The update workload will update
    existing orders. The read workload will retrieve data for existing
    orders.

    .Parameter Throttle
    The number of threads that will process tasks in parallel. Think of
    this as the number of registers in the coffee shop.

    .Example
    .\run.ps1 -TaskCount 10 `
	    -WorkLoadType Write `
	    -Throttle 3 `
        -Verbose
    
    Generate a write workload against the Coffee database. Workload will
    have three threads.

    .Example
    .\run.ps1 -TaskCount 10 `
	    -WorkLoadType Read `
	    -Throttle 2 `
        -Verbose
    
    Generate a write workload against the Coffee database. Workload will
    have two threads.
    
    .Example
    .\run.ps1 -TaskCount 10 `
	    -WorkLoadType Update `
	    -Throttle 4 `
        -Verbose
        
    Generate a write workload against the Coffee database. Workload will
    have four threads.
   
    .Notes
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
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true, Position=1)]
    [int64] $TaskCount
  , [Parameter(Mandatory=$true, Position=2)]
    [ValidateSet("Read","Write","Update")]
    [string] $WorkLoadType
  , [Parameter(Mandatory=$false, Position=3)]
    [int] $Throttle = 4
) 

Set-StrictMode -Version 4.0

## Load libraries
. .\Coffee.Thread.ps1

## Initialize
$self_path = $script:MyInvocation.MyCommand.Path    
$self_directory = Split-Path -Path $self_path -Parent

$coffee_library_workload = 'Coffee.Application.ps1'
$coffee_library_workload_path = `
    Join-Path -Path $self_directory -ChildPath $coffee_library_workload

$coffee_library_thread = '.\Coffee.Thread.ps1'
$coffee_library_thread_path = `
    Join-Path -Path $self_directory -ChildPath $coffee_library_thread

## Create workload scripts
$string_create_control_thread = Get-Content .\Coffee.Script-ControlThread.ps1 -Raw
$script_create_control_thread = [ScriptBlock]::Create($string_create_control_thread)

## Create control thread for workload
Initialize-Thread -ScriptBlock $script_create_control_thread `
    -ArgumentList $coffee_library_workload_path `
        , $coffee_library_thread_path `
        , $TaskCount `
        , $WorkloadType `
        , $Throttle