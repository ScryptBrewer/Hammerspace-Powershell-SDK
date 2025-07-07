function Start-HammerspaceAssimilation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Volume,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Share,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter()]
        [switch]$MonitorTask
    )
    
    begin {
        if (-not $Global:HammerspaceSession) {
            throw "No active Hammerspace session. Please run Connect-Hammerspace first."
        }
    }
    
    process {
        try {
            # Build the URI with query parameters
            $uri = "storage-volumes/$Volume/assimilation"
            $queryParams = @{
                path = $Path
                share = $Share
                sourcePath = $SourcePath
            }
            
            # Convert query parameters to string
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object {
                "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))"
            }) -join '&'
            
            $fullUri = "${uri}?${queryString}"
            
            Write-Verbose "Starting assimilation on volume: $Volume"
            Write-Verbose "Path: $Path, Share: $Share, SourcePath: $SourcePath"
            
            # Make the request
            $response = Invoke-HammerspaceRequest -Method 'POST' -Endpoint $fullUri
            
            if ($MonitorTask -and $response.taskUri) {
                Write-Verbose "Monitoring assimilation task..."
                $task = Wait-HammerspaceTask -TaskUri $response.taskUri
                return $task
            }
            
            return $response
        }
        catch {
            throw "Failed to start assimilation: $_"
        }
    }
}

# Alias for convenience
Set-Alias -Name Start-HSAssimilation -Value Start-HammerspaceAssimilation