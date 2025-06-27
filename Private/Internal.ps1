# Private/Internal.ps1
# Contains the core internal functions for making API calls and monitoring tasks.
# NOTE: The RequiredAssemblies key in the .psd1 manifest handles loading System.Web.

function Invoke-HammerspaceRestCall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Path,
        [Parameter(Mandatory=$false)] [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")] [string]$Method = "GET",
        [Parameter(Mandatory=$false)] [hashtable]$BodyData,
        [Parameter(Mandatory=$false)] [ValidateSet("Json", "Form")] [string]$BodyFormat = "Json",
        [Parameter(Mandatory=$false)] [hashtable]$QueryParams,
        [Parameter(Mandatory=$false)] [hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)] [bool]$IsLogin = $false,
        [Parameter(Mandatory=$false)] [bool]$IsAbsoluteUrl = $false,
        [Parameter(Mandatory=$false)] [bool]$IsRetryAfterRelogin = $false
    )
    
    if ($script:HammerspaceSession.Username -and -not $IsLogin -and -not $IsRetryAfterRelogin -and -not $script:HammerspaceSession.IsLoggedIn) {
        Write-Verbose "Not logged in. Attempting login before API call."
        try { Invoke-HammerspaceLogin } catch { Write-Error "Pre-call login attempt failed: $_"; throw }
    }
    
    $url = if ($IsAbsoluteUrl) { $Path } else { "$($script:HammerspaceSession.BaseUrl)$($Path.TrimStart('/'))" }
    
    $restParams = @{
        Uri = $url; Method = $Method; Headers = $Headers
        WebSession = $script:HammerspaceSession.Session; TimeoutSec = $script:HammerspaceSession.Timeout
    }
    
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $script:HammerspaceSession.VerifySSL) {
        $restParams.SkipCertificateCheck = $true
    }
    
    if ($BodyData -and $Method -in @('POST', 'PUT', 'PATCH')) {
        if ($BodyFormat -eq "Json") {
            $restParams.Body = $BodyData | ConvertTo-Json -Depth 10
            $restParams.ContentType = "application/json"
        } else {
            $restParams.Body = $BodyData
        }
    }
    
    if ($QueryParams -and $QueryParams.Count -gt 0) {
        $uriBuilder = New-Object System.UriBuilder($url)
        $queryCollection = [System.Web.HttpUtility]::ParseQueryString($uriBuilder.Query)
        foreach ($key in $QueryParams.Keys) {
            if ($QueryParams[$key] -ne $null) {
                if ($QueryParams[$key] -is [array]) { foreach ($item in $QueryParams[$key]) { $queryCollection.Add($key, $item.ToString()) } }
                else { $queryCollection.Add($key, $QueryParams[$key].ToString()) }
            }
        }
        $uriBuilder.Query = $queryCollection.ToString(); $restParams.Uri = $uriBuilder.ToString()
    }
    
    Write-Verbose "Request: $Method $($restParams.Uri)"
    
    try {
        if ($Method -eq 'DELETE') {
            $deleteParams = $restParams.Clone()
            $deleteParams.Headers.Add('Accept', 'application/json')
            return Invoke-RestMethod @deleteParams
        } else {
            return Invoke-RestMethod @restParams
        }
    }
    catch {
        # Gracefully handle expected empty response for DELETE (though API seems to return a task)
        if ($Method -eq 'DELETE' -and $_.Exception.Response -and $_.Exception.Response.StatusCode -eq 'NoContent') {
            Write-Verbose "DELETE request succeeded with no content in response."
            return $true
        }
        
        # Re-throw any other unexpected errors
        throw
    }
}

# The Invoke-HammerspaceTaskMonitor function does not need to be changed.
function Invoke-HammerspaceTaskMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$ResourcePath,
        [Parameter(Mandatory=$true)] [string]$Method,
        [Parameter(Mandatory=$false)] [hashtable]$Data,
        [Parameter(Mandatory=$false)] [hashtable]$QueryParams,
        [Parameter(Mandatory=$false)] [int]$PollInterval = 5,
        [Parameter(Mandatory=$false)] [int]$Timeout = 300
    )

    try {
        $restCallParams = @{ Path = $ResourcePath; Method = $Method }
        if ($Data) { $restCallParams.BodyData = $Data; $restCallParams.BodyFormat = 'Json' }
        if ($QueryParams) { $restCallParams.QueryParams = $QueryParams }
        $initialResponse = Invoke-HammerspaceRestCall @restCallParams
    }
    catch {
        throw "Invoke-HammerspaceTaskMonitor: Initial API call failed for $Method $ResourcePath during task execution: $($_.Exception.Message)"
    }

    if ($initialResponse -is [bool] -and $initialResponse -eq $true) {
        Write-Host "Operation completed successfully without returning a task." -ForegroundColor Green
        return $initialResponse
    }

    if (-not $initialResponse.taskUuid) {
        Write-Warning "API response for $Method $ResourcePath did not return a task UUID. Returning initial response."
        return $initialResponse
    }

    $taskUuid = $initialResponse.taskUuid
    Write-Host "Task started with UUID: $taskUuid. Monitoring progress..." -ForegroundColor Green

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        $taskStatus = Get-HammerspaceTask -Uuid $taskUuid
        if ($taskStatus) {
            Write-Progress -Activity "Monitoring Task ($taskUuid)" -Status $taskStatus.state -PercentComplete $taskStatus.percentComplete
            if ($taskStatus.state -eq 'COMPLETED') {
                $stopwatch.Stop(); Write-Host "Task $taskUuid completed successfully." -ForegroundColor Green; return $taskStatus
            }
            elseif ($taskStatus.state -in @('FAILED', 'CANCELED')) {
                $stopwatch.Stop(); $errorMessage = "Task $taskUuid finished with status: $($taskStatus.state)."; if ($taskStatus.statusMessage) { $errorMessage += " Message: $($taskStatus.statusMessage)" }; throw $errorMessage
            }
        } else { Write-Warning "Could not retrieve status for task $taskUuid. Will retry." }
        Start-Sleep -Seconds $PollInterval
    }
    $stopwatch.Stop()
    throw "Task monitoring timed out after $Timeout seconds for task $taskUuid."
}