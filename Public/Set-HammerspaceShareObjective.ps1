function Set-HammerspaceShareObjective {
    <#
    .SYNOPSIS
        Sets one or more objectives on a Hammerspace share.

    .DESCRIPTION
        This cmdlet applies one or more objectives to a specified share. Objectives control data placement,
        protection, and other behaviors. This action is additive; it does not remove existing objectives.
        It requires an active session established by `Connect-Hammerspace`.

    .PARAMETER ShareName
        The name of the share on which to set the objective(s).

    .PARAMETER ObjectiveIdentifier
        The name of the objective(s) to apply to the share. This can be a single string or an array of strings.

    .EXAMPLE
        PS C:\> Set-HammerspaceShareObjective -ShareName "myshare" -ObjectiveIdentifier "place-on-myvol"

        This command applies the "place-on-myvol" objective to the share named "myshare".

    .EXAMPLE
        PS C:\> Set-HammerspaceShareObjective -ShareName "critical-data" -ObjectiveIdentifier "replicate-to-dr", "archive-after-90d"

        This command applies two separate objectives to the "critical-data" share.

    .LINK
        https://github.com/ScryptBrewer/Hammerspace-Powershell-SDK
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The name of the share to modify.")]
        [string]$ShareName,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the objective(s) to apply.")]
        [string[]]$ObjectiveIdentifier
    )

    begin {
        if (-not ($Global:HammerspaceSession -and $Global:HammerspaceSession.IsConnected)) {
            throw "No active Hammerspace session found. Please connect using Connect-Hammerspace first."
        }
    }

    process {
        foreach ($objective in $ObjectiveIdentifier) {
            try {
                $targetResource = "Objective '$objective' on Share '$ShareName'"
                if ($PSCmdlet.ShouldProcess($targetResource, "Set Hammerspace Share Objective")) {

                    # The API endpoint is constructed with the share name and the objective as a query parameter.
                    $Uri = "$($Global:HammerspaceSession.BaseUri)/v1.2/rest/shares/$ShareName/objective-set?objective-identifier=$objective"

                    Write-Verbose "POSTing to URI: $Uri"

                    # This is a POST request with an empty body, as seen in the curl example.
                    $result = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Global:HammerspaceSession.Headers

                    Write-Host "Successfully applied objective '$objective' to share '$ShareName'."
                    $result | Out-Host
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
                Write-Error "Failed to set objective '$objective' on share '$ShareName'. API Error: $errorMessage"
            }
        }
    }
}