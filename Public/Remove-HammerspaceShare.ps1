# Public/Remove-HammerspaceShare.ps1
# Contains the user-facing function for removing a share.

function Remove-HammerspaceShare {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
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