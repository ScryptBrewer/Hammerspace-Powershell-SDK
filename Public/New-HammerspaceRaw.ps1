# Public/New-HammerspaceRaw.ps1
# Contains the function for creating a new resource with a POST request.

function New-HammerspaceRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourcePath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Data,
        
        [Parameter(Mandatory=$false)]
        [switch]$MonitorTask
    )

    if ($MonitorTask) {
        Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'POST' -Data $Data
    }
    else {
        Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'POST' -BodyData $Data -BodyFormat "Json"
    }
}