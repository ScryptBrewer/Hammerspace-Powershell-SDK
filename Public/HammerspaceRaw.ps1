# Public/HammerspaceRaw.ps1
# Contains functions for making generic GET, POST, PUT, and DELETE requests to the Hammerspace API.

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
        return Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'GET' -QueryParams $QueryParams
    }
    catch {
        Write-Error "Failed to get resource from '$ResourcePath'. Error: $_"
    }
}

function New-HammerspaceRaw {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourcePath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Data,
        
        [Parameter(Mandatory=$false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Creates a new resource using the Hammerspace API.

    .DESCRIPTION
        This function sends a POST request to a specified Hammerspace API endpoint to create a new resource.
        It can optionally monitor the asynchronous task that the API may return.

    .PARAMETER ResourcePath
        The path to the API resource collection where the new resource will be created, e.g., "shares".

    .PARAMETER Data
        A hashtable containing the data for the new resource. This will be converted to a JSON body for the request.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the task created by the API call until it completes.

    .EXAMPLE
        # Create a new share
        $shareData = @{
            name = "MyNewShare"
            sharePath = "/mnt/my-new-share"
            exportOptions = @(
                @{
                    path = "/"
                    clients = "192.168.1.0/24(rw,no_root_squash)"
                }
            )
        }
        New-HammerspaceRaw -ResourcePath "shares" -Data $shareData

    .EXAMPLE
        # Create a new objective and monitor the creation task
        $objectiveData = @{
            name = "MyReplicationObjective"
            action = "REPLICATE"
            # ... other objective properties
        }
        New-HammerspaceRaw -ResourcePath "objectives" -Data $objectiveData -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        If -MonitorTask is not used, returns the initial API response (often a task object).
        If -MonitorTask is used, returns the final, completed task object.
    #>

    if ($MonitorTask) {
        Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'POST' -Data $Data
    }
    else {
        Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'POST' -BodyData $Data -BodyFormat "Json"
    }
}

function Set-HammerspaceRaw {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ResourcePath,

        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable]$Properties,

        [Parameter(Mandatory = $false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Safely updates an existing resource at a specified raw API path.

    .DESCRIPTION
        This function provides a safe and robust method to update any resource in Hammerspace.
        It follows a critical "get, then update" pattern to prevent accidental data loss.

        The function first performs a GET request to retrieve the resource's complete and current state.
        It then applies the provided property changes to this local object. If a property in the update
        does not exist on the retrieved object (a common issue with optional fields), it will be added.
        Finally, it performs a PUT request, sending the entire modified object back to the API.

        This ensures that you only change what you intend to change, and all other settings on the
        resource remain intact.

    .PARAMETER ResourcePath
        The full path to the specific API resource to be updated. This must be a path to a single item,
        usually including its UUID.
        Example: "shares/7dceba09-12da-42d3-ba5f-72d60a75028d"

    .PARAMETER Properties
        A hashtable of properties and their new values to apply to the resource.
        Example: @{ comment = "New Comment"; extendedAttributes = @{ "owner" = "John" } }

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the update task created by the API call
        until it completes.

    .EXAMPLE
        # Update the comment on a specific objective by its UUID
        $props = @{ comment = "This objective is now for high-priority replication." }
        Set-HammerspaceRaw -ResourcePath "objectives/a1b2c3d4-e5f6-7890-1234-567890abcdef" -Properties $props -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        If -MonitorTask is not used, returns the initial API response.
        If -MonitorTask is used, returns the final, completed task object.
    #>
    try {
        Write-Verbose "Getting current object state from '$ResourcePath'"
        $currentObject = Get-HammerspaceRaw -ResourcePath $ResourcePath

        if (-not $currentObject) {
            throw "Could not retrieve object at path '$ResourcePath'. Cannot perform update."
        }

        Write-Verbose "Applying property updates to the local object."
        foreach ($key in $Properties.Keys) {
            if (-not ($currentObject.PSObject.Properties.Name -contains $key)) {
                Write-Verbose "Property '$key' not found on object, adding it."
                $currentObject | Add-Member -MemberType NoteProperty -Name $key -Value $Properties[$key]
            }
            else {
                $currentObject.$key = $Properties[$key]
            }
        }

        Write-Verbose "Converting the updated PSCustomObject back to a Hashtable for the API call."
        $bodyHashtable = @{}
        foreach ($prop in $currentObject.PSObject.Properties) {
            $bodyHashtable[$prop.Name] = $prop.Value
        }

        if ($PSCmdlet.ShouldProcess($ResourcePath, "Update (PUT) with modified properties")) {
            if ($MonitorTask) {
                Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'PUT' -Data $bodyHashtable
            }
            else {
                Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'PUT' -BodyData $bodyHashtable
            }
        }
    }
    catch {
        Write-Error "Failed to update resource at '$ResourcePath'. Error: $_"
    }
}

function Remove-HammerspaceRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourcePath,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$QueryParams,

        [Parameter(Mandatory=$false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Removes a resource using the Hammerspace API.

    .DESCRIPTION
        This function sends a DELETE request to a specified Hammerspace API resource path to remove it.
        It can optionally monitor the asynchronous task that the API may return for the deletion process.

    .PARAMETER ResourcePath
        The full path to the specific API resource to be deleted, e.g., "shares/7dceba09-12da-42d3-ba5f-72d60a75028d".

    .PARAMETER QueryParams
        A hashtable of optional query parameters to append to the URL.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the deletion task created by the API call until it completes.

    .EXAMPLE
        # Delete a specific share by its UUID
        Remove-HammerspaceRaw -ResourcePath "shares/7dceba09-12da-42d3-ba5f-72d60a75028d"

    .EXAMPLE
        # Delete a snapshot and monitor the deletion task
        Remove-HammerspaceRaw -ResourcePath "snapshots/a1b2c3d4-e5f6-7890-1234-567890abcdef" -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        If -MonitorTask is not used, returns the initial API response.
        If -MonitorTask is used, returns the final, completed task object.
    #>

    if ($MonitorTask) {
        Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'DELETE' -QueryParams $QueryParams
    }
    else {
        Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'DELETE' -QueryParams $QueryParams
    }
}