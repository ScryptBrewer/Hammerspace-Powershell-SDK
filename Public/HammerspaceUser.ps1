# Public/HammerspaceUser.ps1
# Contains functions for managing Hammerspace users.

function Get-HammerspaceUser {
    [CmdletBinding(DefaultParameterSetName='GetAll')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Username,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [string]$Id,

        [Parameter(Mandatory=$true, ParameterSetName='ByFilter')]
        [string[]]$Filter,

        [Parameter()]
        [switch]$Full
    )
    <#
    .SYNOPSIS
        Retrieves Hammerspace users.

    .DESCRIPTION
        This function retrieves information about Hammerspace users. It can fetch all users,
        a specific user by username or UUID, or a filtered list of users.

        By default, it returns a summarized, custom object for easy viewing. Use the -Full
        parameter to get the complete, raw object from the API with all available properties.

    .PARAMETER Username
        The exact username of the user to retrieve.

    .PARAMETER Id
        The UUID of the user to retrieve.

    .PARAMETER Filter
        An array of filter strings to apply to the query, following the Hammerspace API spec format.
        Example: "username=co=admin" to find all users with 'admin' in their username.

    .PARAMETER Full
        If specified, returns the complete, raw user object from the API instead of the default summary view.

    .EXAMPLE
        # Get a summary list of all users
        Get-HammerspaceUser

    .EXAMPLE
        # Get the full object for a specific user by username
        Get-HammerspaceUser -Username "john" -Full

    .EXAMPLE
        # Get a user by its UUID
        Get-HammerspaceUser -Id "9efd14ce-b4a2-452d-86ed-8ca5e4a0635e"

    .EXAMPLE
        # Get all users with data access role S3
        Get-HammerspaceUser -Filter "dataAccessRoles=co=S3"

    .OUTPUTS
        System.Management.Automation.PSCustomObject or System.Management.Automation.PSObject
        Returns a custom summary object by default, or the full PSObject if -Full is specified.
    #>
    $queryParams = @{}
    $resourcePath = 'users'

    switch ($PSCmdlet.ParameterSetName) {
        'ByName'   { $queryParams.spec = "username=eq=$Username" }
        'ById'     { $resourcePath = "users/$Id" }
        'ByFilter' { $queryParams.spec = $Filter }
        'GetAll'   { Write-Verbose "No specific filter provided. Getting all users." }
    }

    try {
        if ($Full) {
            $users = Invoke-HammerspaceRestCall -Path $resourcePath -QueryParams $queryParams -Full
            if ($null -eq $users) { return }
            return $users
        }
        else {
            $users = Invoke-HammerspaceRestCall -Path $resourcePath -QueryParams $queryParams
            if ($null -eq $users) { return }
            $userList = if ($users -is [array]) { $users } else { @($users) }
            foreach ($user in $userList) {
                $managementRoleName = if ($user.managementRole) { $user.managementRole.name } else { $null }
                [PSCustomObject]@{
                    Username        = $user.username
                    UUID            = $user.uoid.uuid
                    FirstName       = $user.firstName
                    LastName        = $user.lastName
                    Email           = $user.email
                    Enabled         = $user.enabled
                    UID             = $user.uid
                    GID             = $user.gid
                    DataAccessRoles = $user.dataAccessRoles
                    ManagementRole  = $managementRoleName
                    Created         = $user.created
                    Modified        = $user.modified
                }
            }
        }
    }
    catch {
        Write-Error "Failed to get Hammerspace users. Error: $_"
    }
}

function New-HammerspaceUser {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Default')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Default')]
        [string]$Username,
        
        [Parameter(Mandatory=$true, ParameterSetName='Default')]
        [string]$Password,
        
        [Parameter(ParameterSetName='Default')]
        [string]$FirstName,
        
        [Parameter(ParameterSetName='Default')]
        [string]$LastName,
        
        [Parameter(ParameterSetName='Default')]
        [string]$Email,
        
        [Parameter(ParameterSetName='Default')]
        [ValidateSet("S3", "SMB")]
        [string[]]$DataAccessRoles,
        
        [Parameter(ParameterSetName='Default')]
        [ValidateSet("admin", "viewer", "dataowner")]
        [string]$ManagementRole,
        
        [Parameter(ParameterSetName='Default')]
        [int]$UID,
        
        [Parameter(ParameterSetName='Default')]
        [int]$GID = 100,
        
        [Parameter(ParameterSetName='Default')]
        [bool]$Enabled = $true,
        
        [Parameter(Mandatory=$true, ParameterSetName='ByDataHashtable', ValueFromPipeline=$true)]
        [hashtable]$UserData,
        
        [Parameter()]
        [switch]$MonitorTask,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    <#
    .SYNOPSIS
        Creates a new Hammerspace user.

    .DESCRIPTION
        This function creates a new user in Hammerspace. You can provide the user's properties
        using individual parameters, or by supplying a single hashtable with all the data.

        A user will either have management access (requiring a management role) or data access
        (which doesn't require any specific data access roles to be selected).

    .PARAMETER Username
        The username for the new user.

    .PARAMETER Password
        The password for the new user.

    .PARAMETER FirstName
        The first name of the user. If not provided, will default to the username.

    .PARAMETER LastName
        The last name of the user.

    .PARAMETER Email
        The email address of the user.

    .PARAMETER DataAccessRoles
        An array of data access roles to assign to the user. Only "S3" and "SMB" are allowed.
        This is for data access users. Do not specify both DataAccessRoles and ManagementRole.

    .PARAMETER ManagementRole
        The management role for the user. Must be one of: "admin", "viewer", or "dataowner".
        This is required for management access users. Do not specify both DataAccessRoles and ManagementRole.

    .PARAMETER UID
        The numeric user ID for the user. If not specified, the system will assign one.

    .PARAMETER GID
        The numeric group ID for the user. Defaults to 100.

    .PARAMETER Enabled
        Whether the user account should be enabled. Defaults to $true.

    .PARAMETER UserData
        A single hashtable containing all the data needed to create the user. This is useful for pipelining.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the creation task until it completes.

    .PARAMETER Timeout
        The timeout in seconds for monitoring the task. Defaults to 300.

    .EXAMPLE
        # Create a management user with admin role
        New-HammerspaceUser -Username "adminuser" -Password "AdminP@ss789" -ManagementRole "admin" -Email "admin@example.com"

    .EXAMPLE
        # Create a data access user with S3 and SMB roles
        New-HammerspaceUser -Username "s3user" -Password "S3P@ss456" -DataAccessRoles @("S3", "SMB")

    .EXAMPLE
        # Create a data access user with no specific roles
        New-HammerspaceUser -Username "datauser" -Password "DataP@ss123" -FirstName "Data" -LastName "User"

    .OUTPUTS
        System.Management.Automation.PSObject
        Returns the task object from the API call.
    #>
    begin {
        $body = $null
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'ByDataHashtable' { 
                    $body = $UserData.Clone()
                    
                    # Ensure password is included
                    if (-not $body.ContainsKey('password')) {
                        throw "UserData must include a 'password' field."
                    }
                    
                    # Set _type to USER if not provided
                    if (-not $body.ContainsKey('_type')) {
                        $body._type = "USER"
                    }
                    
                    # Validate access type (management vs data access)
                    $hasManagementRole = $body.ContainsKey('managementRole') -and $body.managementRole
                    $hasDataAccessRoles = $body.ContainsKey('dataAccessRoles') -and $body.dataAccessRoles -and $body.dataAccessRoles.Count -gt 0
                    
                    # If management role is provided, validate it
                    if ($hasManagementRole) {
                        if ($body.managementRole -is [string]) {
                            if ($body.managementRole -notin @("admin", "viewer", "dataowner")) {
                                throw "Invalid ManagementRole: '$($body.managementRole)'. Only 'admin', 'viewer', and 'dataowner' are allowed."
                            }
                            # Convert string to required format
                            $body.managementRole = @{ name = $body.managementRole }
                        }
                        elseif ($body.managementRole -is [hashtable] -and $body.managementRole.ContainsKey('name')) {
                            if ($body.managementRole.name -notin @("admin", "viewer", "dataowner")) {
                                throw "Invalid ManagementRole: '$($body.managementRole.name)'. Only 'admin', 'viewer', and 'dataowner' are allowed."
                            }
                        }
                    }
                    
                    # Validate DataAccessRoles if provided
                    if ($hasDataAccessRoles) {
                        foreach ($role in $body.dataAccessRoles) {
                            if ($role -notin @("S3", "SMB")) {
                                throw "Invalid DataAccessRole: '$role'. Only 'S3' and 'SMB' are allowed."
                            }
                        }
                    }
                    
                    # Set username to firstName if firstName is not provided
                    if (-not $body.ContainsKey('firstName') -or [string]::IsNullOrWhiteSpace($body.firstName)) {
                        $body.firstName = $body.username
                    }
                }
                'Default' {
                    $body = @{
                        _type = "USER"
                        username = $Username
                        password = $Password
                        enabled = $Enabled
                    }
                    
                    # Set firstName to username if not provided
                    if ($PSBoundParameters.ContainsKey('FirstName')) { 
                        $body.firstName = $FirstName 
                    } else {
                        $body.firstName = $Username
                    }
                    
                    if ($PSBoundParameters.ContainsKey('LastName')) { $body.lastName = $LastName }
                    if ($PSBoundParameters.ContainsKey('Email')) { $body.email = $Email }
                    
                    # Handle DataAccessRoles and ManagementRole
                    $hasManagementRole = $PSBoundParameters.ContainsKey('ManagementRole')
                    $hasDataAccessRoles = $PSBoundParameters.ContainsKey('DataAccessRoles')
                    
                    if ($hasManagementRole) { 
                        $body.managementRole = @{ name = $ManagementRole }
                    }
                    
                    if ($hasDataAccessRoles) { 
                        $body.dataAccessRoles = $DataAccessRoles 
                    }
                    
                    if ($PSBoundParameters.ContainsKey('UID')) { $body.uid = $UID }
                    if ($PSBoundParameters.ContainsKey('GID')) { $body.gid = $GID }
                }
            }
            
            # Validate the user has either management access (with role) or data access (with or without roles)
            $hasManagementRole = $body.ContainsKey('managementRole') -and $body.managementRole
            $hasDataAccessRoles = $body.ContainsKey('dataAccessRoles') -and $body.dataAccessRoles -and $body.dataAccessRoles.Count -gt 0
            
            # If management role is provided, ensure it's valid
            if ($hasManagementRole) {
                # Management role is already validated above
                Write-Verbose "Creating a management access user with role: $($body.managementRole.name)"
            } else {
                # This is a data access user (with or without specific roles)
                Write-Verbose "Creating a data access user$(if ($hasDataAccessRoles) { " with roles: $($body.dataAccessRoles -join ', ')" } else { " with no specific roles" })"
            }
            
            if ($pscmdlet.ShouldProcess($body.username, "Create User")) {
                Write-Verbose "Submitting POST request to create user '$($body.username)'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath 'users' -Method 'POST' -Data $body -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path 'users' -Method 'POST' -BodyData $body
                }
            }
        }
        catch {
            Write-Error "Failed to create Hammerspace user. Error: $_"
        }
    }
}

function Set-HammerspaceUser {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Username,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable]$Properties,
        
        [Parameter(Mandatory = $false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Safely updates properties of an existing Hammerspace user.

    .DESCRIPTION
        This is a high-level function for updating a user by its username. It follows the critical
        "get, then update" pattern to prevent accidental data loss.

        The function will find the user by its username to get its UUID, then retrieve the full user object.
        It then applies the specified property changes and sends the entire modified object back to the API.
        This prevents accidental data loss and handles missing optional properties gracefully.

        A user will either have management access (requiring a management role) or data access
        (which doesn't require any specific data access roles to be selected).

    .PARAMETER Username
        The username of the user to update.

    .PARAMETER Properties
        A hashtable of properties and their new values to apply to the user.
        Example: @{ email = "newemail@example.com"; enabled = $false }

        For DataAccessRoles, only "S3" and "SMB" are allowed.
        For ManagementRole, only "admin", "viewer", and "dataowner" are allowed.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the update task created by the API call
        until it completes.

    .EXAMPLE
        # Update the email and last name for a user
        $updates = @{
            email = "john.doe@example.com"
            lastName = "Doe-Smith"
        }
        Set-HammerspaceUser -Username "jdoe" -Properties $updates -MonitorTask

    .EXAMPLE
        # Change a user's data access roles
        Set-HammerspaceUser -Username "s3user" -Properties @{ dataAccessRoles = @("S3") }

    .EXAMPLE
        # Convert a data access user to a management user
        Set-HammerspaceUser -Username "datauser" -Properties @{ 
            managementRole = "viewer"
            dataAccessRoles = @()
        }

    .OUTPUTS
        System.Management.Automation.PSObject
        The final task object from the update operation.
    #>
    try {
        # Validate DataAccessRoles if provided
        if ($Properties.ContainsKey('dataAccessRoles') -and $Properties.dataAccessRoles) {
            foreach ($role in $Properties.dataAccessRoles) {
                if ($role -notin @("S3", "SMB")) {
                    throw "Invalid DataAccessRole: '$role'. Only 'S3' and 'SMB' are allowed."
                }
            }
        }
        
        # Validate ManagementRole if provided
        if ($Properties.ContainsKey('managementRole')) {
            if ($Properties.managementRole -is [string]) {
                if ($Properties.managementRole -notin @("admin", "viewer", "dataowner")) {
                    throw "Invalid ManagementRole: '$($Properties.managementRole)'. Only 'admin', 'viewer', and 'dataowner' are allowed."
                }
                # Convert string to required format
                $Properties.managementRole = @{ name = $Properties.managementRole }
            }
            elseif ($Properties.managementRole -is [hashtable] -and $Properties.managementRole.ContainsKey('name')) {
                if ($Properties.managementRole.name -notin @("admin", "viewer", "dataowner")) {
                    throw "Invalid ManagementRole: '$($Properties.managementRole.name)'. Only 'admin', 'viewer', and 'dataowner' are allowed."
                }
            }
        }
        
        # Ensure _type is USER
        if (-not $Properties.ContainsKey('_type')) {
            $Properties._type = "USER"
        }
        
        Write-Verbose "Finding user '$Username' to get its UUID."
        $user = Get-HammerspaceUser -Username $Username -Full
        if (-not $user) {
            throw "User with username '$Username' not found."
        }
        
        # Get the current state to determine if we're changing access type
        $currentHasManagementRole = $null -ne $user.managementRole
        $willHaveManagementRole = $Properties.ContainsKey('managementRole') ? 
                                 ($null -ne $Properties.managementRole) : 
                                 $currentHasManagementRole
        
        # Log the access type change if applicable
        if ($currentHasManagementRole -ne $willHaveManagementRole) {
            if ($willHaveManagementRole) {
                Write-Verbose "Converting user from data access to management access with role: $($Properties.managementRole.name)"
            } else {
                Write-Verbose "Converting user from management access to data access"
            }
        }
        
        $resourcePath = "users/$($user.uoid.uuid)"
        if ($PSCmdlet.ShouldProcess($Username, "Update User Properties")) {
            # This internal function performs the get-then-update logic
            return Set-HammerspaceRaw -ResourcePath $resourcePath -Properties $Properties -MonitorTask:$MonitorTask
        }
    }
    catch {
        Write-Error "Failed to update user '$Username'. Error: $_"
    }
}

function Remove-HammerspaceUser {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ById', ValueFromPipelineByPropertyName=$true)]
        [string]$Id,
        
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Username,
        
        [Parameter(Mandatory=$true, ParameterSetName='ByInputObject', ValueFromPipeline=$true)]
        [psobject]$InputObject,
        
        [Parameter()]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Removes an existing Hammerspace user.

    .DESCRIPTION
        This function removes a Hammerspace user. It can identify the user to be removed
        by its username, its UUID, or by passing a user object directly to it (e.g., from a pipeline).

        Because this is a destructive operation, it has a high confirmation impact and will prompt
        for confirmation before proceeding unless -Confirm:$false is used.

    .PARAMETER Id
        The UUID of the user to remove.

    .PARAMETER Username
        The username of the user to remove.

    .PARAMETER InputObject
        A user object (e.g., from Get-HammerspaceUser) to be removed.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the deletion task until it completes.

    .EXAMPLE
        # Remove a user by username
        Remove-HammerspaceUser -Username "tempuser"

    .EXAMPLE
        # Remove a user by ID without confirmation
        Remove-HammerspaceUser -Id "9efd14ce-b4a2-452d-86ed-8ca5e4a0635e" -Confirm:$false

    .EXAMPLE
        # Find a user and pipe it to Remove-HammerspaceUser
        Get-HammerspaceUser -Username "olduser" | Remove-HammerspaceUser -MonitorTask

    .OUTPUTS
        System.Management.Automation.PSObject
        Returns the task object from the API call.
    #>
    begin {
        $usersToDelete = @()
    }
    process {
        $user = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ById'   { $user = Get-HammerspaceUser -Id $Id -Full }
            'ByName' { $user = Get-HammerspaceUser -Username $Username -Full }
            'ByInputObject' { $user = $InputObject }
        }
        if ($user) { $usersToDelete += $user }
    }
    end {
        if ($usersToDelete.Count -eq 0) { Write-Warning "No users found to remove."; return }
        foreach ($user in $usersToDelete) {
            $userId = if ($user.uoid) { $user.uoid.uuid } elseif ($user.UUID) { $user.UUID } else { $null }
            $userName = if ($user.username) { $user.username } else { "with ID $userId" }
            if (-not $userId) {
                Write-Error "Could not determine the UUID for user '$userName'. Cannot proceed."
                continue
            }
            $resourcePath = "users/$userId"
            if ($pscmdlet.ShouldProcess($userName, "Remove user (Path: $resourcePath)")) {
                try {
                    Remove-HammerspaceRaw -ResourcePath $resourcePath -MonitorTask:$MonitorTask
                    Write-Host "Successfully initiated removal for user '$userName' (ID: $userId)."
                }
                catch {
                    Write-Error "Failed to remove user '$userName' (ID: $userId). Error: $_"
                }
            }
        }
    }
}

function Set-HammerspaceUserPassword {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Username,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$NewPassword,
        
        [Parameter(Mandatory = $false)]
        [switch]$MonitorTask
    )
    <#
    .SYNOPSIS
        Updates the password for an existing Hammerspace user.

    .DESCRIPTION
        This function provides a specialized way to update just the password for a user.
        It's a convenience wrapper around Set-HammerspaceUser that focuses only on password changes.

    .PARAMETER Username
        The username of the user whose password should be changed.

    .PARAMETER NewPassword
        The new password to set for the user.

    .PARAMETER MonitorTask
        If specified, the function will monitor the progress of the update task created by the API call
        until it completes.

    .EXAMPLE
        # Change a user's password
        Set-HammerspaceUserPassword -Username "jdoe" -NewPassword "NewSecureP@ss456"

    .OUTPUTS
        System.Management.Automation.PSObject
        The final task object from the update operation.
    #>
    try {
        $properties = @{
            _type = "USER"
            password = $NewPassword
        }
        
        if ($PSCmdlet.ShouldProcess($Username, "Update User Password")) {
            return Set-HammerspaceUser -Username $Username -Properties $properties -MonitorTask:$MonitorTask
        }
    }
    catch {
        Write-Error "Failed to update password for user '$Username'. Error: $_"
    }
}