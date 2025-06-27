# Public/Get-HammerspaceTask.ps1
# Contains the function to retrieve the status of a specific task by its UUID.

function Get-HammerspaceTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uuid
    )

    $resourcePath = "tasks/$Uuid"

    try {
        return Invoke-HammerspaceRestCall -Path $resourcePath
    }
    catch {
        Write-Error "Failed to retrieve status for task '$Uuid'. Error: $_"
    }
}