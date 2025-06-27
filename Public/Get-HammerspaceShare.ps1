# Contains the Get-HammerspaceShare function for retrieving share information.

function Get-HammerspaceShare {
    # --- CHANGE 1: Define a default parameter set ---
    [CmdletBinding(DefaultParameterSetName='GetAll')]
    param(
        # --- CHANGE 2: Make parameters mandatory within their set ---
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [string]$Id,

        [Parameter(Mandatory=$true, ParameterSetName='ByFilter')]
        [string[]]$Filter,

        [Parameter()]
        [switch]$Full
    )

    $queryParams = @{}
    $resourcePath = 'shares'

    # The switch statement now correctly handles the new 'GetAll' default.
    switch ($PSCmdlet.ParameterSetName) {
        'ByName'   { $queryParams.spec = "name=eq=$Name" }
        'ById'     { $resourcePath = "shares/$Id" }
        'ByFilter' { $queryParams.spec = $Filter }
        'GetAll'   { # Fetch all shares.
                     Write-Verbose "No specific filter provided. Getting all shares." 
                   }
    }

    try {
        $shares = Invoke-HammerspaceRestCall -Path $resourcePath -QueryParams $queryParams
        
        if ($null -eq $shares) { return }

        if ($Full) {
            return $shares
        }
        else {
            $shareList = if ($shares -is [array]) { $shares } else { @($shares) }

            foreach ($share in $shareList) {
                [PSCustomObject]@{
                    Name       = $share.name
                    Path       = $share.path
                    UUID       = $share.uoid.uuid
                    Created    = if ($share.created) { Convert-HammerspaceTimeToDateTime -Timestamp $share.created } else { $null }
                    Modified   = if ($share.modified) { Convert-HammerspaceTimeToDateTime -Timestamp $share.modified } else { $null }
                    Objectives = $share.shareObjectives
                    Exports    = $share.exportOptions
                }
            }
        }
    }
    catch {
        Write-Error "Failed to get Hammerspace shares. Error: $_"
    }
}