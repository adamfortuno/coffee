function Get-ThreadStatus {
	Param (
        [Parameter(Mandatory)][Hashtable]$thread
	)
	
	"Completed: {0}" -f $thread.thread_handle.IsCompleted
	"HasErrors: {0}" -f $thread.session.HadErrors
	
	if ( $thread.session.HadErrors ) {
		$thread.session.Streams.Errors
	}
}

function Get-ThreadResult {
	Param (
		[Parameter(Mandatory)][Hashtable]$thread
	)

	if ( $thread.thread_handle.IsCompleted ) {
		$thread.session.EndInvoke($thread.thread_handle)
	} else {
		throw "Thread is still running."
	}
}
function Initialize-Thread {
    Param(
        [Parameter(Mandatory=$true,Position=1)][scriptblock]$ScriptBlock
      , [Parameter(Mandatory=$false,Position=2)][object[]]$ArgumentList
    )

    $runspace = [runspacefactory]::CreateRunspace()
    $session = [PowerShell]::Create()
    $session.runspace = $runspace
    $runspace.Open()
    $session.AddScript($ScriptBlock, $true) | Out-Null
    
    if ( $ArgumentList -ne $null ) {
        $session.AddParameters($ArgumentList) | Out-Null
    }

    return @{'session' = $session; 'thread_handle' = $session.BeginInvoke() }
}

function Initialize-ThreadPool {
    Param(
        [Parameter(Mandatory=$true,Position=1)][scriptblock] $ScriptBlock
      , [Parameter(Mandatory=$false,Position=2)][Hashtable] $Parameters
      , [Parameter(Mandatory=$true,Position=3)][int64] $Occurrences
      , [Parameter(Mandatory=$false,Position=4)][int] $Throttle = 3
    )
    
    [pscustomobject[]]$threads_all = @()

    [runspacefactory]::CreateRunspacePool() | Out-Null

    $session_state = `
        [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    $runspace_pool = [runspacefactory]::CreateRunspacePool(1, $Throttle)
    $runspace_pool.ApartmentState = "STA"
    $runspace_pool.Open()

    for ($iterator = 1; $iterator -le $Occurrences; $iterator++) {
        
        $session = [Powershell]::Create()
        $session.AddScript($ScriptBlock, $false) | Out-Null
        if ( $Parameters ) {
            $session.AddParameters($Parameters) | Out-Null
        
        }
        $session.RunspacePool = $runspace_pool
        
        $thread_created = [pscustomobject]@{
            'session' = $session
            'thread_handle' = $session.BeginInvoke()
            'IsActive' = $True
        }

        $threads_all += $thread_created
    }

    Write-Output -NoEnumerate -InputObject $threads_all
}