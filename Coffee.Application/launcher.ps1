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
Set-StrictMode -Version 5.0

$time_test_start = $(Get-Date).AddMinutes(1).ToShortTimeString()

. .\Coffee.Analyze
. .\Coffee.Thread

"{0}: Starting test at {1}" -f $(Get-Date).ToShortTimeString(), $time_test_start

while ( $(Get-Date) -le [datetime]$time_test_start ) {
	Start-Sleep 1
}

"{0}: Starting test..." -f $(Get-Date).ToShortTimeString()

"{0}: ...starting write test" -f $(Get-Date).ToShortTimeString()

$testWrite = .\run.ps1 -TaskCount 35000 `
-WorkLoadType Write `
-Throttle 5 `
-Verbose

"{0}: ...starting read test" -f $(Get-Date).ToShortTimeString()

$testRead = .\run.ps1 -TaskCount 35000 `
-WorkLoadType Read `
-Throttle 5 `
-Verbose

"{0}: ...starting update test" -f $(Get-Date).ToShortTimeString()

$testUpdate = .\run.ps1 -TaskCount 30000 `
-WorkLoadType Update `
-Throttle 5 `
-Verbose

"{0}: All test workloads started" -f $(Get-Date).ToShortTimeString()

$completed_workloads = 0
$write_result_summary = $Null
$read_result_summary = $Null
$update_result_summary = $Null

while ($completed_workloads -lt 3) {
    Start-Sleep -Seconds 60
    "{0}: ....Check: There are {1} completed workloads" -f $(Get-Date).ToShortTimeString(), $completed_workloads

	if ( $testWrite.thread_handle.isCompleted -and $write_result_summary -eq $null ) {
		$write_result_detail, $write_result_summary = Get-ThreadResult $testWrite
        $completed_workloads++
        "{0}: Write workload completed..." -f $(Get-Date).ToShortTimeString()
	}

	if ( $testRead.thread_handle.isCompleted -and $read_result_summary -eq $null ) {
		$read_result_detail, $read_result_summary = Get-ThreadResult $testRead
        $completed_workloads++
        "{0}: Read workload completed..." -f $(Get-Date).ToShortTimeString()
	}

	if ( $testUpdate.thread_handle.isCompleted -and $update_result_summary -eq $null ) {
		$update_result_detail, $update_result_summary = Get-ThreadResult $testUpdate
        $completed_workloads++
        "{0}: Update workload completed..." -f $(Get-Date).ToShortTimeString()
	}
}

Export-CoffeeTestSummary -TestSummary $write_result_summary, $read_result_summary, $update_result_summary
Export-CoffeeTestDetail -TestDetail $write_result_detail, $read_result_detail, $update_result_detail