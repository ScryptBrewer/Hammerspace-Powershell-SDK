# Public/Get-HammerspaceRaw.ps1
# Contains the Get-HammerspaceRaw function for making generic GET requests to the API.

function Get-HammerspaceRaw {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ResourcePath,

        [Parameter(Mandatory=$false)]
        [hashtable]$QueryParams
    )

    <#
    .SYNOPSIS
        Retrieves raw data from a specified Hammerspace API resource path.

    .DESCRIPTION
        This function is a generic wrapper that performs a GET request to any given endpoint
        in the Hammerspace API. It is useful for accessing data from resources that do not
        have a dedicated high-level function.

    .PARAMETER ResourcePath
        The path to the API resource, e.g., "shares", "objectives", or "tasks/some-uuid".

    .PARAMETER QueryParams
        A hashtable of optional query parameters to append to the URL, such as for filtering or sorting.
        Example: @{ spec = "name=eq=MyShare" }

    .EXAMPLE
        # Get all objectives
        Get-HammerspaceRaw -ResourcePath "objectives"

    .EXAMPLE
        # Get a specific share by its UUID
        Get-HammerspaceRaw -ResourcePath "shares/7dceba09-12da-42d3-ba5f-72d60a75028d"

    .EXAMPLE
        # Get all shares with a specific filter
        Get-HammerspaceRaw -ResourcePath "shares" -QueryParams @{ spec = "site.name=eq=MySite" }

    .OUTPUTS
        System.Management.Automation.PSObject
        The raw object or array of objects returned by the API.
    #>

    try {
        # Call the internal REST function with the specified path and query parameters.
        # The method is always 'GET' for this function.
        return Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'GET' -QueryParams $QueryParams
    }
    catch {
        Write-Error "Failed to get resource from '$ResourcePath'. Error: $_"
    }
}