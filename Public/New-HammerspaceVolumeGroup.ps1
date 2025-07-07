function New-HammerspaceVolumeGroup {
    <#
    .SYNOPSIS
        Creates a new Volume Group in Hammerspace.

    .DESCRIPTION
        This cmdlet creates a new Volume Group and populates it with one or more existing storage volumes.
        Volume Groups are used to define placement and objective policies for shares.
        It requires an active session established by `Connect-Hammerspace`.

    .PARAMETER Name
        The unique name for the new Volume Group.

    .PARAMETER VolumeName
        The name of the storage volume(s) to include in this group. You can provide a single volume name or an array of them.

    .EXAMPLE
        PS C:\> New-HammerspaceVolumeGroup -Name "MyWebAppTier" -VolumeName "MyObjectvolume"

        This command creates a new Volume Group named "MyWebAppTier" and adds the single volume "MyObjectvolume" to it.

    .EXAMPLE
        PS C:\> New-HammerspaceVolumeGroup -Name "ArchiveGroup" -VolumeName "ArchiveVol1", "ArchiveVol2"

        This command creates a new Volume Group named "ArchiveGroup" and includes two volumes in it.

    .LINK
        https://github.com/ScryptBrewer/Hammerspace-Powershell-SDK
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The unique name for the new Volume Group.")]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the volume(s) to include in the group.")]
        [string[]]$VolumeName
    )

    begin {
        if (-not ($Global:HammerspaceSession -and $Global:HammerspaceSession.IsConnected)) {
            throw "No active Hammerspace session found. Please connect using Connect-Hammerspace first."
        }
        $Uri = "$($Global:HammerspaceSession.BaseUri)/v1.2/rest/volume-groups"
    }

    process {
        try {
            $targetResource = "Volume Group '$Name' with volumes: $($VolumeName -join ', ')"
            if ($PSCmdlet.ShouldProcess($targetResource, "Create Hammerspace Volume Group")) {

                # Build the locations array by looping through the provided volume names
                $locations = foreach ($volume in $VolumeName) {
                    @{
                        _type         = "VOLUME_LOCATION"
                        storageVolume = @{
                            _type = "OBJECT_STORAGE_VOLUME" # As seen in your example
                            name  = $volume
                        }
                    }
                }

                # Construct the final request body
                $bodyObject = @{
                    _type       = "VOLUME_GROUP"
                    name        = $Name
                    expressions = @(
                        @{
                            operator  = "IN"
                            locations = $locations
                        }
                    )
                }

                $bodyJson = $bodyObject | ConvertTo-Json -Depth 5

                Write-Verbose "POSTing to URI: $Uri"
                Write-Verbose "Request Body: $bodyJson"

                $result = Invoke-RestMethod -Method Post -Uri $Uri -Body $bodyJson -ContentType 'application/json' -Headers $Global:HammerspaceSession.Headers

                Write-Host "Successfully created Volume Group '$Name'."
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
            Write-Error "Failed to create Volume Group '$Name'. API Error: $errorMessage"
        }
    }
}