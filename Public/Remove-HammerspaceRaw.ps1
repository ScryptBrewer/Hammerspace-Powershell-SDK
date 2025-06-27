# Public/Remove-HammerspaceRaw.ps1
# Contains the generic function for deleting a resource by its full resource path.

function Remove-HammerspaceRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourcePath,
        
        # --- ADD THIS PARAMETER ---
        [Parameter(Mandatory=$false)]
        [hashtable]$QueryParams,

        [Parameter(Mandatory=$false)]
        [switch]$MonitorTask
    )

    if ($MonitorTask) {
        Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'DELETE' -QueryParams $QueryParams
    }
    else {
        Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'DELETE' -QueryParams $QueryParams
    }
}