# hammerspaceUtil.ps1
# Utility functions for common Hammerspace API operations

function Get-HammerspacePermittedOperations {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Gets the operations that the current user has access to.

    .DESCRIPTION
        This function retrieves the list of permitted operations for the currently authenticated user.
        This is useful for determining what actions the user can perform in the Hammerspace system.

    .PARAMETER Full
        If specified, returns the full, unmodified object from the API without any formatting.

    .EXAMPLE
        # Get permitted operations with default formatting
        Get-HammerspacePermittedOperations

    .EXAMPLE
        # Get raw permitted operations data
        Get-HammerspacePermittedOperations -Full

    .OUTPUTS
        System.Management.Automation.PSObject
        An object containing the list of operations the current user can perform.
    #>

    try {
        Get-HammerspaceRaw -ResourcePath "users/_current/permitted-operations" -Full:$Full.IsPresent
    }
    catch {
        Write-Error "Failed to get permitted operations for current user. Error: $_"
    }
}

function Get-HammerspaceController {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Gets the current state of the Hammerspace controller.

    .DESCRIPTION
        This function retrieves the current state and status information of the Hammerspace controller.
        This includes system health, operational status, and other controller-level information.

    .PARAMETER Full
        If specified, returns the full, unmodified object from the API without any formatting.

    .EXAMPLE
        # Get controller state with default formatting
        Get-HammerspaceController

    .EXAMPLE
        # Get raw controller state data
        Get-HammerspaceController -Full

    .OUTPUTS
        System.Management.Automation.PSObject
        An object containing the current controller state and status information.
    #>

    try {
        Get-HammerspaceRaw -ResourcePath "cntl/state" -Full:$Full.IsPresent
    }
    catch {
        Write-Error "Failed to get controller state. Error: $_"
    }
}

function Get-HammerspaceSmtp {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Gets the current SMTP configuration settings.

    .DESCRIPTION
        This function retrieves the SMTP mail server configuration settings from Hammerspace.
        This includes server details, authentication settings, and other email-related configuration.

    .PARAMETER Full
        If specified, returns the full, unmodified object from the API without any formatting.

    .EXAMPLE
        # Get SMTP settings with default formatting
        Get-HammerspaceSmtp

    .EXAMPLE
        # Get raw SMTP configuration data
        Get-HammerspaceSmtp -Full

    .OUTPUTS
        System.Management.Automation.PSObject
        An object containing the current SMTP configuration settings.
    #>

    try {
        Get-HammerspaceRaw -ResourcePath "mail/smtp" -Full:$Full.IsPresent
    }
    catch {
        Write-Error "Failed to get SMTP configuration. Error: $_"
    }
}

function Get-HammerspaceCurrentUser {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Gets information about the currently authenticated user.

    .DESCRIPTION
        This function retrieves detailed information about the user account that is currently
        authenticated with the Hammerspace API, including user properties, roles, and permissions.

    .PARAMETER Full
        If specified, returns the full, unmodified object from the API without any formatting.

    .EXAMPLE
        # Get current user information with default formatting
        Get-HammerspaceCurrentUser

    .EXAMPLE
        # Get raw current user data
        Get-HammerspaceCurrentUser -Full

    .OUTPUTS
        System.Management.Automation.PSObject
        An object containing information about the currently authenticated user.
    #>

    try {
        Get-HammerspaceRaw -ResourcePath "users/_current" -Full:$Full.IsPresent
    }
    catch {
        Write-Error "Failed to get current user information. Error: $_"
    }
}
