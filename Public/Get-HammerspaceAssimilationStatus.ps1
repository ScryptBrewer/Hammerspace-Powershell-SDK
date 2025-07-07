function Get-HammerspaceAssimilationStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Volume,
        
        [Parameter()]
        [string]$Path
    )
    
    begin {
        if (-not $Global:HammerspaceSession) {
            throw "No active Hammerspace session. Please run Connect-Hammerspace first."
        }
    }
    
    process {
        try {
            $uri = "storage-volumes/$Volume/assimilation"
            
            if ($Path) {
                $uri += "?path=$([System.Uri]::EscapeDataString($Path))"
            }
            
            $response = Invoke-HammerspaceRequest -Method 'GET' -Endpoint $uri
            return $response
        }
        catch {
            throw "Failed to get assimilation status: $_"
        }
    }
}