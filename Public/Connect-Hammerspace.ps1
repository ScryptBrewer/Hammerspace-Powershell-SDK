# Public/Connect-Hammerspace.ps1
# A convenience function to initialize and log in in a single step.

function Connect-Hammerspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cluster,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 8443,
        
        [Parameter(Mandatory = $false)]
        [bool]$VerifySSL = $false
    )

    try {
        Initialize-HammerspaceConnection -Cluster $Cluster -Credential $Credential -Port $Port -VerifySSL:$VerifySSL
        
        Invoke-HammerspaceLogin

        Write-Host "Successfully connected to Hammerspace cluster: $Cluster" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Hammerspace cluster '$Cluster'. Error: $_"
    }
}