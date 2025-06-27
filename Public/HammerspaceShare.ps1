# Public/HammerspaceShare.ps1
# Contains functions for managing Hammerspace shares.

function Get-HammerspaceShare {
    [CmdletBinding(DefaultParameterSetName='GetAll')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [string]$Id,

        [Parameter(Mandatory=$true, ParameterSetName='ByFilter')]
        [string[]]$Filter,

        [Parameter()]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Retrieves Hammerspace shares.

    .DESCRIPTION
        This function retrieves information about Hammerspace shares. It can fetch all shares,
        a specific share by its name or UUID, or a filtered list of shares.

        By default, it returns a summarized, custom object for easy viewing. Use the -Full
        parameter to get the complete, raw object from the API with all available properties.

    .PARAMETER Name
        The exact name of the share to retrieve.

    .PARAMETER Id
        The UUID of the share to retrieve.

    .PARAMETER Filter
        An array of filter strings to apply to the query, following the Hammerspace API spec format.
        Example: "name=co=project" to find all shares with 'project' in their name.

    .PARAMETER Full
        If specified, returns the complete, raw share object from the API instead of the default summary view.

    .EXAMPLE
        # Get a summary list of all shares
        Get-HammerspaceShare

    .EXAMPLE
        # Get the full object for a specific share by name
        Get-HammerspaceShare -Name "my-data-share" -Full

    .EXAMPLE
        # Get a share by its UUID
        Get-HammerspaceShare -Id "7dceba09-12da-42d3-ba5f-72d60a75028d"

    .EXAMPLE
        # Get all shares larger than 100GB
        Get-HammerspaceShare -Filter "shareSizeLimit=gt=107374182400"

    .OUTPUTS
        System.Management.Automation.PSCustomObject or System.Management.Automation.PSObject
        Returns a custom summary object by default, or the full PSObject if -Full is specified.
    #>
    $queryParams = @{}
    $resourcePath = 'shares'

    switch ($PSCmdlet.ParameterSetName) {
        'ByName'   { $queryParams.spec = "name=eq=$Name" }
        'ById'     { $resourcePath = "shares/$Id" }
        'ByFilter' { $queryParams.spec = $Filter }
        'GetAll'   { Write-Verbose "No specific filter provided. Getting all shares." }
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

function New-HammerspaceShare {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Default')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Default')]
        [string]$Name,
        [Parameter(Mandatory=$false, Position=1, ParameterSetName='Default')]
        [string]$Path,
        [Parameter(ParameterSetName='Default')]
        [string]$Comment,
        [Parameter(ParameterSetName='Default')]
        [hashtable[]]$ExportOptions,
        [Parameter(ParameterSetName='Default')]
        [hashtable[]]$ShareObjectives,
        [Parameter(ParameterSetName='Default')]
        [long]$ShareSizeLimit,
        [Parameter(ParameterSetName='Default')]
        [int]$WarnUtilizationPercentThreshold,
        [Parameter(ParameterSetName='Default')]
        [switch]$SmbBrowsable,
        [Parameter(Mandatory=$true, ParameterSetName='ByDataHashtable', ValueFromPipeline=$true)]
        [hashtable]$ShareData,
        [Parameter()]
        [switch]$MonitorTask,
        [Parameter()]
        [int]$Timeout = 300
    )
    <#
    .SYNOPSIS
        Creates a new Hammerspace share.

    .DESCRIPTION
        This function creates a new share in Hammerspace. You can provide the share's properties
        using individual parameters, or by supplying a single hashtable with all the data.

        If the -Path parameter is not provided, it will default to a path based on the share's name (e.g., "/MyShare").

    .PARAMETER Name
        The name for the new share.

    .PARAMETER Path
        The mount path for the new share. Defaults to "/<Name>" if not specified.

    .PARAMETER Comment
        An optional descriptive comment for the share.

    .PARAMETER ExportOptions
        An array of hashtables defining the NFS export options for the share.

    .PARAMETER ShareObjectives
        An array of hashtables defining the objectives to be applied to the share.

    .PARAMETER ShareSizeLimit
        The size limit for the share in bytes.

    .PARAMETER WarnUtilizationPercentThreshold
        The utilization percentage at which to trigger a warning.

    .PARAMETER SmbBrowsable
        If specified, makes the share browsable via SMB.

    .PARAMETER ShareData
        A single hashtable containing all the data needed to create the share. This is useful for pipelining.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the creation task until it completes.

    .PARAMETER Timeout
        The timeout in seconds for monitoring the task. Defaults to 300.

    .EXAMPLE
        # Create a simple share, letting the path default to "/web-assets"
        New-HammerspaceShare -Name "web-assets" -Comment "Assets for the main website"

    .EXAMPLE
        # Create a more complex share with a size limit and export options, and monitor the task
        $exports = @{ path = "/"; clients = "192.168.1.0/24(rw,no_root_squash)" }
        New-HammerspaceShare -Name "db-backups" -ShareSizeLimit 2TB -ExportOptions $exports -MonitorTask

    .EXAMPLE
        # Create a share using a data hashtable
        $data = @{
            name = "finance-docs"
            path = "/finance"
            comment = "Confidential finance documents"
        }
        New-HammerspaceShare -ShareData $data

    .OUTPUTS
        System.Management.Automation.PSObject
        Returns the task object from the API call.
    #>
    begin {
        $body = $null
    }
    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Default' -and -not $PSBoundParameters.ContainsKey('Path')) {
                $Path = "/$Name"
                Write-Verbose "Path parameter not provided. Defaulting path to '$Path'."
            }
            switch ($PSCmdlet.ParameterSetName) {
                'ByDataHashtable' { $body = $ShareData }
                'Default' {
                    $body = @{}
                    $body.name = $Name
                    $body.path = $Path
                    if ($PSBoundParameters.ContainsKey('Comment')) { $body.comment = $Comment }
                    if ($PSBoundParameters.ContainsKey('ExportOptions')) { $body.exportOptions = $ExportOptions }
                    if ($PSBoundParameters.ContainsKey('ShareObjectives')) { $body.shareObjectives = $ShareObjectives }
                    if ($PSBoundParameters.ContainsKey('ShareSizeLimit')) { $body.shareSizeLimit = $ShareSizeLimit }
                    if ($PSBoundParameters.ContainsKey('WarnUtilizationPercentThreshold')) { $body.warnUtilizationPercentThreshold = $WarnUtilizationPercentThreshold }
                    if ($PSBoundParameters.ContainsKey('SmbBrowsable')) { $body.smbBrowsable = $SmbBrowsable.IsPresent }
                }
            }
            if ($pscmdlet.ShouldProcess($body.name, "Create Share (Path: $($body.path))")) {
                Write-Verbose "Submitting POST request to create share '$($body.name)'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath 'shares' -Method 'POST' -Data $body -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path 'shares' -Method 'POST' -BodyData $body
                }
            }
        }
        catch {
            Write-Error "Failed to create Hammerspace share. Error: $_"
        }
    }
}

function Set-HammerspaceShare {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable]$Properties,
        [Parameter(Mandatory = $false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Safely updates properties of an existing Hammerspace share.

    .DESCRIPTION
        This is a high-level function for updating a share by its name. It follows the critical
        "get, then update" pattern to prevent accidental data loss.

        The function will find the share by its name to get its UUID, then retrieve the full share object.
        It then applies the specified property changes and sends the entire modified object back to the API.
        This prevents accidental data loss and handles missing optional properties gracefully.

    .PARAMETER Name
        The name of the share to update.

    .PARAMETER Properties
        A hashtable of properties and their new values to apply to the share.
        Example: @{ comment = "Updated for the finance department"; shareSizeLimit = 100GB }

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the update task created by the API call
        until it completes.

    .EXAMPLE
        # Update the comment and size limit for a share named 'project-data'
        $updates = @{
            comment = "Data for Project Phoenix"
            shareSizeLimit = 500 * 1GB # 500GB
        }
        Set-HammerspaceShare -Name "project-data" -Properties $updates -MonitorTask

    .EXAMPLE
        # Clear the user mappings on a share
        Set-HammerspaceShare -Name "archive-share" -Properties @{ userMappings = @() }

    .OUTPUTS
        System.Management.Automation.PSObject
        The final task object from the update operation.
    #>
    try {
        Write-Verbose "Finding share '$Name' to get its UUID."
        $share = Get-HammerspaceShare -Name $Name -Full # Use -Full to get the complete object
        if (-not $share) {
            throw "Share with name '$Name' not found."
        }
        $resourcePath = "shares/$($share.uoid.uuid)"
        if ($PSCmdlet.ShouldProcess($Name, "Update Share Properties")) {
            # This internal function performs the get-then-update logic
            return Set-HammerspaceRaw -ResourcePath $resourcePath -Properties $Properties -MonitorTask:$MonitorTask
        }
    }
    catch {
        Write-Error "Failed to update share '$Name'. Error: $_"
    }
}

function Remove-HammerspaceShare {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ById', ValueFromPipelineByPropertyName=$true)]
        [string]$Id,
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,
        [Parameter(Mandatory=$true, ParameterSetName='ByInputObject', ValueFromPipeline=$true)]
        [psobject]$InputObject,
        [Parameter()]
        [int]$DeleteDelay = 24,
        [Parameter()]
        [bool]$DeletePath = $true,
        [Parameter()]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Removes an existing Hammerspace share.

    .DESCRIPTION
        This function removes a Hammerspace share. It can identify the share to be removed
        by its name, its UUID, or by passing a share object directly to it (e.g., from a pipeline).

        Because this is a destructive operation, it has a high confirmation impact and will prompt
        for confirmation before proceeding unless -Confirm:$false is used.

    .PARAMETER Id
        The UUID of the share to remove.

    .PARAMETER Name
        The name of the share to remove.

    .PARAMETER InputObject
        A share object (e.g., from Get-HammerspaceShare) to be removed.

    .PARAMETER DeleteDelay
        The delay in hours before the share is permanently deleted. Defaults to 24.

    .PARAMETER DeletePath
        Specifies whether to delete the data within the share's path. Defaults to $true.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the deletion task until it completes.

    .EXAMPLE
        # Remove a share by its name, accepting the default prompts and delays
        Remove-HammerspaceShare -Name "old-project-share"

    .EXAMPLE
        # Remove a share by ID with a 48-hour delay, and keep the underlying data
        Remove-HammerspaceShare -Id "7dceba09-12da-42d3-ba5f-72d60a75028d" -DeleteDelay 48 -DeletePath $false

    .EXAMPLE
        # Find a share and pipe it to Remove-HammerspaceShare
        Get-HammerspaceShare -Name "temp-share" | Remove-HammerspaceShare -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        Returns the task object from the API call.
    #>
    begin {
        $sharesToDelete = @()
    }
    process {
        $share = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ById'   { $share = Get-HammerspaceShare -Id $Id -Full }
            'ByName' { $share = Get-HammerspaceShare -Name $Name -Full }
            'ByInputObject' { $share = $InputObject }
        }
        if ($share) { $sharesToDelete += $share }
    }
    end {
        if ($sharesToDelete.Count -eq 0) { Write-Warning "No shares found to remove."; return }
        foreach ($share in $sharesToDelete) {
            $shareId = if ($share.uoid) { $share.uoid.uuid } elseif ($share.UUID) { $share.UUID } else { $null }
            $shareName = if ($share.name) { $share.name } else { "with ID $shareId" }
            if (-not $shareId) {
                Write-Error "Could not determine the UUID for share '$shareName'. Cannot proceed."
                continue
            }
            $resourcePath = "shares/$shareId"
            if ($pscmdlet.ShouldProcess($shareName, "Remove share (Path: $resourcePath)")) {
                try {
                    $queryParams = @{
                        'delete-delay' = $DeleteDelay
                        'delete-path'  = $DeletePath.ToString().ToLower()
                    }
                    Remove-HammerspaceRaw -ResourcePath $resourcePath -QueryParams $queryParams -MonitorTask:$MonitorTask
                    Write-Host "Successfully initiated removal for share '$shareName' (ID: $shareId)."
                }
                catch {
                    Write-Error "Failed to remove share '$shareName' (ID: $shareId). Error: $_"
                }
            }
        }
    }
}