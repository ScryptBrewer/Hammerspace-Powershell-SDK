# Hammerspace PowerShell Module
[PowerShell Version 5.1+] 
[Module Version: 1.0]

A powerful, user-friendly PowerShell module for interacting with the Hammerspace Anvil API. This module provides a set of intuitive cmdlets to manage shares, monitor tasks, and perform raw API operations against a Hammerspace cluster.
## Features:
- ***Simplified Connection Management:*** Securely connect and re-authenticate to your Hammerspace cluster.
- ***Full Share Lifecycle Management:*** Create, retrieve, and remove shares with ease.
- ***Asynchronous Task Monitoring:*** Initiate long-running operations and monitor them to completion.
- ***SNMP Configuration:*** Manage and test SNMP settings directly from PowerShell.
- ***Advanced "Raw" Access:*** Provides direct access to API endpoints for maximum flexibility.
- ***Pipeline Support:*** Pipe objects between cmdlets for efficient scripting.
- ***Best Practices:*** Encourages secure credential storage and includes
  WhatIf/-Confirm support for destructive operations.

## Requirements

    PowerShell 5.1 or later.
    Network access to a Hammerspace cluster's management interface (port 8443 by default).

## Getting Started
### 1. Get the Code
Clone the repository to your local machine.
```powershell

git clone https://github.com/ScryptBrewer/Hammerspace-Powershell-SDK.git
```

### 2. Load the Module
Navigate to the project directory and import the module into your PowerShell session.
```powershell

# Import the module
Import-Module ./Hammerspace-Powershell-SDK/HammerspaceModule.psd1
```

### 3. Connect to Your Hammerspace Cluster
Connecting is simple and secure. The recommended method is to use the Connect-Hammerspace wrapper function with a stored credential file.First-Time Setup (Create a Secure Credential File): This is the most secure way to handle credentials, as it avoids saving your password in plain text scripts.

```powershell

# This will prompt you for your Hammerspace username and password
$cred = Get-Credential

# Encrypt and save the credential object to a file for later use
$cred | Export-Clixml -Path "C:\Path\To\Your\HammerspaceCreds.xml"
```

Connecting in Your Scripts:

```powershell

# Import the securely stored credential
$credential = Import-Clixml -Path "C:\Path\To\Your\HammerspaceCreds.xml"

# Connect to the cluster using the credential object
Connect-Hammerspace -Cluster "your-cluster-name.hammerspace.com" -Credential $credential
```

You are now connected and ready to run commands!
Basic Operations & Examples
Here’s how to use the primary functions in the module.
### Managing Shares
Get a List of All Shares

```powershell

# Get a summarized list of all shares
Get-HammerspaceShare

# Get the full, detailed JSON object for all shares
Get-HammerspaceShare -Full
```
#### Get a Specific Share
```powershell

# Get a share by its name
Get-HammerspaceShare -Name "MyWebAppShare"

# Get a share by its UUID
Get-HammerspaceShare -Id "7dceba09-12da-42d3-ba5f-72d60a75028d"
```
#### Create a New Share
```powershell

# Simple creation: Name is required, Path is auto-generated as /mnt/shares/<Name>
New-HammerspaceShare -Name "MyNewShare" -MonitorTask

# Advanced creation with custom path, exports, and objectives
$export = New-HammerspaceExportOption -Subnet "10.0.0.0/8" -AccessPermissions "RW"
$objective = New-HammerspaceShareObjective -ObjectiveName "keep-online"

New-HammerspaceShare -Name "MyAdvancedShare" `
    -Path "/mnt/custom/advanced" `
    -ExportOptions $export `
    -ShareObjectives $objective `
    -ShareSizeLimit 2000000000000 `
    -MonitorTask
```
#### Remove a Share
The Remove-HammerspaceShare cmdlet supports -WhatIf and -Confirm to prevent accidental deletion.
```powershell

# See what would happen without actually deleting
Remove-HammerspaceShare -Name "MyNewShare" -WhatIf

# Remove a share by name (will prompt for confirmation)
Remove-HammerspaceShare -Name "MyNewShare"

# Remove a share and bypass the confirmation prompt
Remove-HammerspaceShare -Name "MyNewShare" -Confirm:$false

# Remove a share but leave the data on the underlying storage path
Remove-HammerspaceShare -Name "archive-share" -DeletePath $false
```
#### Managing SNMP
```powershell

# Get the current SNMP configuration
Get-HammerspaceSnmpConfiguration

# Create a new SNMPv3 configuration
$snmpConfig = @{
    version = "V3"
    # ... other SNMP parameters
}
New-HammerspaceSnmpConfiguration -Configuration $snmpConfig

# Send a test trap
Test-HammerspaceSnmpNotification
```
#### Monitoring Tasks
```powershell

# Get the status of a specific task by its UUID
Get-HammerspaceTask -Uuid "a1b2c3d4-e5f6-a7b8-c9d0-e1f2a3b4c5d6"
```
#### Advanced Usage: The "Raw" Functions
For maximum flexibility, the module includes "raw" functions that allow you to interact with any API endpoint, even those without a dedicated, user-friendly wrapper.
#####Get-HammerspaceRaw
Performs a GET request to any resource path.
```powershell

# Get a list of all defined objectives
Get-HammerspaceRaw -ResourcePath "objectives"

# Get a list of all sites
Get-HammerspaceRaw -ResourcePath "sites"
```
##### New-HammerspaceRaw
Performs a POST request to create a new resource.
```powershell

# Example: Create a new resource at a custom endpoint
$newData = @{
    name = "SomeNewItem"
    value = "SomeValue"
}
New-HammerspaceRaw -ResourcePath "custom-resources" -Data $newData -MonitorTask
```
##### Remove-HammerspaceRaw
Performs a DELETE request on a specific resource path.
```powershell

# Example: Delete a specific task by its UUID
$taskUuid = "a1b2c3d4-e5f6-a7b8-c9d0-e1f2a3b4c5d6"
Remove-HammerspaceRaw -ResourcePath "tasks/$taskUuid"
```
### Consolidated list of ResourcePath resources:
        ad
        antivirus
        backup
        base-storage-volumes
        cntl
        data-analytics
        data-copy-to-object
        data-portals
        disk-drives
        dnss
        domain-idmaps
        events
        file-snapshots
        files
        gateways
        heartbeat
        i18n
        identity
        identity-group-mappings
        idp
        kmses
        labels
        ldaps
        license-server
        licenses
        logical-volumes
        login
        login-policy
        mailsmtp
        metrics
        modeler
        network-interfaces
        nis
        nodes
        notification-rules
        ntps
        object-storage-volumes
        object-store-logical-volumes
        object-stores
        objectives
        pd-node-cntl
        pd-support
        processor
        reports
        roles
        s3server
        schedules
        share-participants
        share-replications
        share-snapshots
        shares
        sites
        snapshot-retentions
        snmp
        static-routes
        storage-volumes
        subnet-gateways
        sw-update
        syslog
        system
        system-info
        tasks
        user-groups
        users
        versions
        volume-groups

## About this Module

    Author: John Olson
    Company: Hammerspace
    Copyright: (c) 2025 John Olson. All rights reserved.
