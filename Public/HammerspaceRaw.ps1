# Public/HammerspaceRaw.ps1
# Contains functions for making generic GET, POST, PUT, and DELETE requests to the Hammerspace API.

function Get-HammerspaceRaw {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ResourcePath,

        [Parameter(Mandatory=$false)]
        [hashtable]$QueryParams,

        [Parameter(Mandatory=$false)]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Retrieves data from a specified Hammerspace API resource path, with optional formatting.

    .DESCRIPTION
        This function performs a GET request to any given endpoint in the Hammerspace API.
        By default, it cleans up the output by removing internal-only fields and converting
        Hammerspace timestamps to standard [DateTime] objects for better readability and usability.

        To get the completely unmodified object from the API, use the -Raw switch. This is
        primarily used by other functions like Set-HammerspaceRaw that need the original object
        structure for updates.

    .PARAMETER ResourcePath
        The path to the API resource, e.g., "shares", "objectives", or "tasks/some-uuid".

    .PARAMETER QueryParams
        A hashtable of optional query parameters to append to the URL, such as for filtering or sorting.
        Example: @{ spec = "name=eq=MyShare" }

    .PARAMETER Full
        If specified, the function returns the full, unmodified object(s) from the API, skipping
        any default formatting or field suppression.

    .EXAMPLE
        # Get all objectives with default formatting
        Get-HammerspaceRaw -ResourcePath "objectives"

    .EXAMPLE
        # Get a specific share by its UUID, which will have timestamps converted
        Get-HammerspaceRaw -ResourcePath "shares/7dceba09-12da-42d3-ba5f-72d60a75028d"

    .EXAMPLE
        # Get the raw, unformatted object for a specific share
        Get-HammerspaceRaw -ResourcePath "shares/7dceba09-12da-42d3-ba5f-72d60a75028d" -Full

    .OUTPUTS
        System.Management.Automation.PSObject
        The formatted or raw object/array of objects returned by the API.
    #>

    try {
        return Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'GET' -QueryParams $QueryParams -Full:$Full.IsPresent
    }
    catch {
        Write-Error "Failed to get resource from '$ResourcePath'. Error: $_"
    }
}

function New-HammerspaceRaw {
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
        Creates a new resource at a specified Hammerspace API resource path.

    .DESCRIPTION
        This function performs a POST request to create a new resource in the Hammerspace API.
        It takes the resource path and a hashtable of properties that define the new resource.

        The function will convert the provided properties hashtable into the appropriate format
        for the API request body and handle the creation process.

        If the API returns a task for asynchronous processing, you can use the -MonitorTask
        switch to wait for completion and get the final result.

    .PARAMETER ResourcePath
        The path to the API resource collection where the new item should be created.
        Example: "shares", "objectives", "volumes"

    .PARAMETER Properties
        A hashtable of properties and their values that define the new resource.
        Example: @{ name = "MyNewShare"; path = "/mnt/share"; exportOptions = "rw" }

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the creation task created by the API call
        until it completes, returning the final result instead of just the initial response.

    .EXAMPLE
        # Create a new share
        $shareProps = @{
            name = "TestShare"
            path = "/mnt/testshare"
            exportOptions = "rw,no_root_squash"
            comment = "Test share created via PowerShell"
        }
        New-HammerspaceRaw -ResourcePath "shares" -Properties $shareProps

    .EXAMPLE
        # Create a new objective and monitor the task
        $objectiveProps = @{
            name = "HighPriorityObjective"
            spec = @{
                source = "/source/path"
                destination = "/dest/path"
                priority = "high"
            }
        }
        New-HammerspaceRaw -ResourcePath "objectives" -Properties $objectiveProps -MonitorTask

    .EXAMPLE
        # Create a new volume with monitoring
        $volumeProps = @{
            name = "DataVolume"
            size = "100GB"
            blockSize = 4096
        }
        New-HammerspaceRaw -ResourcePath "volumes" -Properties $volumeProps -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        If -MonitorTask is not used, returns the initial API response from the creation.
        If -MonitorTask is used, returns the final, completed task object.

    .NOTES
        This function creates new resources in Hammerspace. The exact properties required
        depend on the type of resource being created. Refer to the Hammerspace API
        documentation for specific property requirements for each resource type.
    #>

    try {
        Write-Verbose "Creating new resource at '$ResourcePath' with provided properties."
        
        # Validate that we have properties to send
        if ($Properties.Count -eq 0) {
            throw "Properties hashtable cannot be empty when creating a new resource."
        }

        Write-Verbose "Converting properties hashtable for API request body."
        $bodyHashtable = @{}
        foreach ($key in $Properties.Keys) {
            $bodyHashtable[$key] = $Properties[$key]
        }

        if ($PSCmdlet.ShouldProcess($ResourcePath, "Create (POST) new resource with specified properties")) {
            if ($MonitorTask) {
                Write-Verbose "Creating resource and monitoring task completion."
                Invoke-HammerspaceTaskMonitor -ResourcePath $ResourcePath -Method 'POST' -Data $bodyHashtable
            }
            else {
                Write-Verbose "Creating resource without task monitoring."
                Invoke-HammerspaceRestCall -Path $ResourcePath -Method 'POST' -BodyData $bodyHashtable
            }
        }
    }
    catch {
        Write-Error "Failed to create new resource at '$ResourcePath'. Error: $_"
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
        $currentObject = Get-HammerspaceRaw -ResourcePath $ResourcePath -Full

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