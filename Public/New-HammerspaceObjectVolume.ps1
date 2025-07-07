function New-HammerspaceObjectVolume {
    <#
    .SYNOPSIS
        Creates a new Object Storage Volume in Hammerspace.

    .DESCRIPTION
        This cmdlet creates a new Object Storage Volume by associating a cloud node with an existing Object Store Logical Volume.
        It requires an active session established by `Connect-Hammerspace`.

    .PARAMETER Name
        The name for the new Object Storage Volume. This name must be unique.

    .PARAMETER NodeName
        The name of the existing cloud node (e.g., an S3 or Azure node) that this volume will be associated with.

    .PARAMETER LogicalVolumeName
        The name of the existing Object Store Logical Volume that will provide the underlying storage.

    .EXAMPLE
        PS C:\> New-HammerspaceObjectVolume -Name "MyWebAppVolume" -NodeName "aws-s3-bucket" -LogicalVolumeName "oslv-01"

        This command creates a new Object Storage Volume named "MyWebAppVolume" on the "aws-s3-bucket" node, using the "oslv-01" logical volume.
        You will be prompted for confirmation before the volume is created.

    .LINK
        https://github.com/ScryptBrewer/Hammerspace-Powershell-SDK
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The unique name for the new Object Storage Volume.")]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the existing cloud node to associate with this volume.")]
        [string]$NodeName,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Object Store Logical Volume.")]
        [string]$LogicalVolumeName
    )

    begin {
        if (-not ($Global:HammerspaceSession -and $Global:HammerspaceSession.IsConnected)) {
            throw "No active Hammerspace session found. Please connect using Connect-Hammerspace first."
        }
        # Based on your curl command, this uses a specific API path.
        $Uri = "$($Global:HammerspaceSession.BaseUri)/v1.2/rest/object-storage-volumes"
    }

    process {
        try {
            $targetResource = "Object Volume '$Name' on Node '$NodeName'"
            if ($PSCmdlet.ShouldProcess($targetResource, "Create Hammerspace Object Volume")) {

                # Construct the request body from the parameters
                $bodyObject = @{
                    _type                    = "OBJECT_STORAGE_VOLUME"
                    name                     = $Name
                    node                     = @{
                        _type = "NODE"
                        name  = $NodeName
                    }
                    objectStoreLogicalVolume = @{
                        _type = "OBJECT_STORE_LOGICAL_VOLUME"
                        name  = $LogicalVolumeName
                    }
                }

                $bodyJson = $bodyObject | ConvertTo-Json -Depth 4

                Write-Verbose "POSTing to URI: $Uri"
                Write-Verbose "Request Body: $bodyJson"

                $result = Invoke-RestMethod -Method Post -Uri $Uri -Body $bodyJson -ContentType 'application/json' -Headers $Global:HammerspaceSession.Headers

                Write-Host "Successfully created Object Storage Volume '$Name'."
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
            Write-Error "Failed to create Object Storage Volume '$Name'. API Error: $errorMessage"
        }
    }
}