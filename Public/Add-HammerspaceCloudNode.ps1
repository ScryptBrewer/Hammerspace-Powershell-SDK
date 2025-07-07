function Add-HammerspaceCloudNode {
    <#
    .SYNOPSIS
        Adds a new cloud storage node to the Hammerspace environment.

    .DESCRIPTION
        This cmdlet adds a new cloud storage target (like Amazon S3, Azure Blob, etc.) as a node in Hammerspace.
        It requires an active session established by `Connect-Hammerspace`. The function securely handles credentials.

    .PARAMETER NodeType
        The type of cloud storage provider.

    .PARAMETER Endpoint
        The API endpoint URL for the cloud storage service.

    .PARAMETER Name
        A unique, friendly name for this cloud node within Hammerspace.

    .PARAMETER Credential
        A PSCredential object containing the authentication details.
        - For the 'Username', provide the cloud provider's Access Key.
        - For the 'Password', provide the cloud provider's Secret Key.

    .EXAMPLE
        PS C:\> $creds = Get-Credential
        PS C:\> Add-HammerspaceCloudNode -NodeType AMAZON_S3 -Endpoint "https://s3.us-east-1.amazonaws.com" -Name "MyS3Archive" -Credential $creds

        This command first prompts you to securely enter your AWS Access Key (as username) and Secret Key (as password).
        Then, it adds a new Amazon S3 node named "MyS3Archive" using those credentials.

    .LINK
        https://github.com/ScryptBrewer/Hammerspace-Powershell-SDK
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the type of cloud node.")]
        [ValidateSet("AMAZON_S3", "ACTIVE_SCALE_S3", "IBM_S3", "CLOUDIAN_S3", "ECS_S3", "GENERIC_S3", "GOOGLE_S3", "SCALITY_S3", "STORAGE_GRID_S3", "AZURE", "GOOGLE_CLOUD", "HCP_S3")]
        [string]$NodeType,

        [Parameter(Mandatory = $true, HelpMessage = "The endpoint URL for the cloud storage service.")]
        [string]$Endpoint,

        [Parameter(Mandatory = $true, HelpMessage = "A unique name for this cloud node.")]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "Credentials for the cloud node. Use Access Key for username and Secret Key for password.")]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {
        if (-not ($Global:HammerspaceSession -and $Global:HammerspaceSession.IsConnected)) {
            throw "No active Hammerspace session found. Please connect using Connect-Hammerspace first."
        }
        $Uri = "$($Global:HammerspaceSession.BaseUri)/v2/nodes"
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess("Cloud Node '$Name' of type '$NodeType'", "Add Hammerspace Cloud Node")) {

                # Construct the request body exactly as specified
                $bodyObject = @{
                    _type               = "NODE"
                    nodeType            = $NodeType
                    endpoint            = $Endpoint
                    name                = $Name
                    mgmtNodeCredentials = @{
                        username = $Credential.UserName
                        password = $Credential.GetNetworkCredential().Password
                    }
                }

                $bodyJson = $bodyObject | ConvertTo-Json -Depth 4

                Write-Verbose "POSTing to URI: $Uri"
                Write-Verbose "Request Body: $bodyJson"

                $result = Invoke-RestMethod -Method Post -Uri $Uri -Body $bodyJson -ContentType 'application/json' -Headers $Global:HammerspaceSession.Headers

                Write-Host "Successfully initiated adding cloud node '$Name'."
                $result | Select-Object *
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($_.Exception.Response) {
                $errorResponse = $_.Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($errorResponse -and $errorResponse.message) {
                    $errorMessage = $errorResponse.message
                }
            }
            Write-Error "Failed to add cloud node '$Name'. API Error: $errorMessage"
        }
    }
}