# Public/New-HammerspaceShareObjective.ps1
# Helper function to create a share objective hashtable.

function New-HammerspaceShareObjective {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ObjectiveName,

        [Parameter()]
        [string]$Applicability = "TRUE",

        [Parameter()]
        [bool]$Removable = $true
    )

    return @{
        objective = @{
            name = $ObjectiveName
        }
        applicability = $Applicability
        removable     = $Removable
    }
}