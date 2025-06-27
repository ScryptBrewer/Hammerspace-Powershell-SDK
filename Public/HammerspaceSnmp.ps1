# Public/HammerspaceSnmp.ps1
# Contains functions for managing Hammerspace SNMP configurations.

<#
.SYNOPSIS
    Gets SNMP configurations from the Hammerspace cluster.
.DESCRIPTION
    Gets all SNMP configurations or a specific SNMP configuration by its identifier.
    This corresponds to the GET /snmp and GET /snmp/{identifier} API endpoints.
.PARAMETER Identifier
    The unique identifier of a specific SNMP configuration to retrieve. If omitted, all configurations are returned.
.PARAMETER Spec
    A filter predicate to apply when listing all configurations.
.PARAMETER Page
    The zero-based page number for pagination when listing all configurations.
.PARAMETER PageSize
    The number of elements per page for pagination.
.PARAMETER PageSort
    The field to sort on when listing all configurations.
.PARAMETER PageSortDir
    The direction to sort ('asc' or 'desc').
.EXAMPLE
    Get-HammerspaceSnmpConfiguration
.EXAMPLE
    Get-HammerspaceSnmpConfiguration -Identifier "snmp-config-uuid"
#>
function Get-HammerspaceSnmpConfiguration {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Identifier,

        # Parameters for listing all configurations
        [Parameter(Mandatory=$false)]
        [string]$Spec,

        [Parameter(Mandatory=$false)]
        [int]$Page,

        [Parameter(Mandatory=$false)]
        [int]$PageSize,

        [Parameter(Mandatory=$false)]
        [string]$PageSort,

        [Parameter(Mandatory=$false)]
        [ValidateSet('asc', 'desc')]
        [string]$PageSortDir
    )

    try {
        $path = '/snmp'
        $queryParams = @{}

        if ($PSBoundParameters.ContainsKey('Identifier')) {
            $path = "/snmp/$Identifier"
            Write-Verbose "Getting SNMP configuration by identifier: $Identifier"
        } else {
            Write-Verbose "Listing all SNMP configurations"
            if ($PSBoundParameters.ContainsKey('Spec')) { $queryParams.'spec' = $Spec }
            if ($PSBoundParameters.ContainsKey('Page')) { $queryParams.'page' = $Page }
            if ($PSBoundParameters.ContainsKey('PageSize')) { $queryParams.'page.size' = $PageSize }
            if ($PSBoundParameters.ContainsKey('PageSort')) { $queryParams.'page.sort' = $PageSort }
            if ($PSBoundParameters.ContainsKey('PageSortDir')) { $queryParams.'page.sort.dir' = $PageSortDir }
        }

        Invoke-HammerspaceRestCall -Path $path -Method 'GET' -QueryParams $queryParams
    }
    catch {
        Write-Error "Failed to get Hammerspace SNMP configuration(s). Error: $_"
    }
}

<#
.SYNOPSIS
    Creates a new SNMP configuration.
.DESCRIPTION
    Creates a new SNMP configuration using the provided data.
    This corresponds to the POST /snmp API endpoint.
.PARAMETER SnmpData
    A hashtable containing the data for the new SNMP configuration. This mirrors the request body of the API call.
.PARAMETER MonitorTask
    If specified, the function will monitor the asynchronous task until completion.
.PARAMETER Timeout
    The timeout in seconds for monitoring the task. Defaults to 300.
.EXAMPLE
    $data = @{ managers = @("10.0.0.1"); communityString = "public" }
    New-HammerspaceSnmpConfiguration -SnmpData $data
#>
function New-HammerspaceSnmpConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]$SnmpData,

        [Parameter()]
        [switch]$MonitorTask,

        [Parameter()]
        [int]$Timeout = 300
    )

    process {
        try {
            if ($pscmdlet.ShouldProcess("New SNMP Configuration", "Create SNMP Configuration")) {
                Write-Verbose "Submitting POST request to create SNMP configuration"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath 'snmp' -Method 'POST' -Data $SnmpData -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path 'snmp' -Method 'POST' -BodyData $SnmpData
                }
            }
        }
        catch {
            Write-Error "Failed to create Hammerspace SNMP configuration. Error: $_"
        }
    }
}

<#
.SYNOPSIS
    Updates an existing SNMP configuration.
.DESCRIPTION
    Updates an existing SNMP configuration identified by its UUID, using the provided data.
    This corresponds to the PUT /snmp/{identifier} API endpoint.
.PARAMETER Identifier
    The unique identifier of the SNMP configuration to update.
.PARAMETER SnmpData
    A hashtable containing the new data for the configuration.
.PARAMETER MonitorTask
    If specified, the function will monitor the asynchronous task until completion.
.PARAMETER Timeout
    The timeout in seconds for monitoring the task. Defaults to 300.
.EXAMPLE
    $data = @{ managers = @("10.0.0.1", "10.0.0.2"); communityString = "private" }
    Set-HammerspaceSnmpConfiguration -Identifier "snmp-config-uuid" -SnmpData $data
#>
function Set-HammerspaceSnmpConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Identifier,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]$SnmpData,

        [Parameter()]
        [switch]$MonitorTask,

        [Parameter()]
        [int]$Timeout = 300
    )

    process {
        try {
            $path = "/snmp/$Identifier"

            if ($pscmdlet.ShouldProcess($Identifier, "Update SNMP Configuration")) {
                Write-Verbose "Submitting PUT request to update SNMP configuration '$Identifier'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath $path -Method 'PUT' -Data $SnmpData -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path $path -Method 'PUT' -BodyData $SnmpData
                }
            }
        }
        catch {
            Write-Error "Failed to update Hammerspace SNMP configuration '$Identifier'. Error: $_"
        }
    }
}

<#
.SYNOPSIS
    Deletes an SNMP configuration.
.DESCRIPTION
    Deletes an SNMP configuration by its identifier.
    This corresponds to the DELETE /snmp/{identifier} API endpoint.
.PARAMETER Identifier
    The unique identifier of the SNMP configuration to delete.
.PARAMETER MonitorTask
    If specified, the function will monitor the asynchronous task until completion.
.PARAMETER Timeout
    The timeout in seconds for monitoring the task. Defaults to 300.
.EXAMPLE
    Remove-HammerspaceSnmpConfiguration -Identifier "snmp-config-uuid"
#>
function Remove-HammerspaceSnmpConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]$Identifier,

        [Parameter()]
        [switch]$MonitorTask,

        [Parameter()]
        [int]$Timeout = 300
    )

    process {
        try {
            $path = "/snmp/$Identifier"

            if ($pscmdlet.ShouldProcess($Identifier, "Delete SNMP Configuration")) {
                Write-Verbose "Submitting DELETE request for SNMP configuration '$Identifier'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath $path -Method 'DELETE' -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path $path -Method 'DELETE'
                }
            }
        }
        catch {
            Write-Error "Failed to delete Hammerspace SNMP configuration '$Identifier'. Error: $_"
        }
    }
}

<#
.SYNOPSIS
    Tests an SNMP notification.
.DESCRIPTION
    Sends a test SNMP notification to a specified address.
    This corresponds to the POST /snmp/test/{address} API endpoint.
.PARAMETER Address
    The IP address or hostname to send the test SNMP notification to.
.PARAMETER MonitorTask
    If specified, the function will monitor the asynchronous task until completion.
.PARAMETER Timeout
    The timeout in seconds for monitoring the task. Defaults to 120.
.EXAMPLE
    Test-HammerspaceSnmpNotification -Address "10.0.0.1"
#>
function Test-HammerspaceSnmpNotification {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Address,

        [Parameter()]
        [switch]$MonitorTask,

        [Parameter()]
        [int]$Timeout = 120
    )

    process {
        try {
            $path = "/snmp/test/$Address"

            if ($pscmdlet.ShouldProcess($Address, "Send Test SNMP Notification")) {
                Write-Verbose "Submitting POST request to test SNMP notification to '$Address'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath $path -Method 'POST' -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path $path -Method 'POST'
                }
            }
        }
        catch {
            Write-Error "Failed to send test SNMP notification to '$Address'. Error: $_"
        }
    }
}