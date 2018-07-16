Set-StrictMode -Version 5.0

function Export-CoffeeTestSummary {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,Position=1)][object[]]$TestSummary
	  , [Parameter(Mandatory=$false,Position=2)][string]$OutputFile
	)

	$initial_export = $true
	$append_to_output = $false

	## Assign a default output file name if one wasn't supplied
	if ( [string]::IsNullOrEmpty($OutputFile) ) {
		$OutputFile = "test_summary_{0}_{1}.csv" `
			-f $env:computerName, $(Get-Date -Format 'yyyyMMdd_hhmmss')
	}
		
	Write-Verbose "Saving results to ${OutputFile}..."
	
	foreach ($test_result in $TestSummary) {
		
		$test_result | Select-Object WorkloadID `
		    , Hostname `
			, Workload `
			, TimeStart `
            , TimeEnd `
            , @{ 'l'='ElapsedTime(ms)';e={$_.Timer.ElapsedMilliseconds} } `
			, CountTasksRequested `
			, WorkerThreads `
		| Export-Csv -Delimiter "`t" `
			-NoTypeInformation `
			-Path ".\${OutputFile}" `
			-Append:$append_to_output `
			-Force

		if ($initial_export) {
			$initial_export = $false
			$append_to_output = $true
		}

	}
}

function Export-CoffeeTestDetail {
	<#
		.Synopsis
		Export Test Results to a File

		.Description
        Exports the results from a workload to a CSV file for
        further evaluation.

		.Parameter Results
		The test result object being exported.
		
		.Parameter Hostname
        The name of the machine on-which the test was run. Defaults
        to the name of the machine the function is being called on.
		
		.Parameter OutputFule
        The path to the output file. If ommitted, it defaults to the
        current directory.

        .Example
        $testRead = .\run.ps1 -TaskCount 2 -WorkLoadType Read -Throttle 2
        $resultRead = $testRead.session.EndInvoke($testRead.thread_handle)

		Export-CoffeeTestDetail -Results $resultRead
		
        .Example
        $testRead = .\run.ps1 -TaskCount 2 -WorkLoadType Read -Throttle 2
        $resultRead = $testRead.session.EndInvoke($testRead.thread_handle)

		Export-CoffeeTestDetail -Results $resultRead -OutputFile '.\thing.csv'
    	#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,Position=1)][object[]]$TestDetail
	  , [Parameter(Mandatory=$false,Position=2)][string]$OutputFile
	)
	
	$initial_export = $true
	$append_to_output = $false

	## Assign a default output file name if one wasn't supplied
	if ( [string]::IsNullOrEmpty($OutputFile) ) {
		$OutputFile = "test_detail_{0}_{1}.csv" `
			-f $env:computerName, $(Get-Date -Format 'yyyyMMdd_hhmmss')
	}
	
	Write-Verbose "Saving results to ${OutputFile}..."
	
	foreach ($result in $TestDetail) {
		
		$result | Select-Object WorkloadID `
			, WorkloadType `
			, Thread `
            , ProcessID `
            , TimeStart `
			, Duration `
			, ErrorCount `
		| Export-Csv -Delimiter "`t" `
			-NoTypeInformation `
			-Path ".\${OutputFile}" `
			-Append:$append_to_output `
			-Force

		if ($initial_export) {
			$initial_export = $false
			$append_to_output = $true
		}

	}
}
