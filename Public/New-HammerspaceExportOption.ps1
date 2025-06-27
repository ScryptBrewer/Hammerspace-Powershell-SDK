# Public/New-HammerspaceExportOption.ps1
# Helper function to create an export option hashtable for a share.

function New-HammerspaceExportOption {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Subnet = "*",

        [Parameter()]
        [ValidateSet("RW", "RO")]
        [string]$AccessPermissions = "RW",

        [Parameter()]
        [switch]$RootSquash,

        [Parameter()]
        [switch]$Insecure
    )

    return @{
        subnet            = $Subnet
        accessPermissions = $AccessPermissions
        rootSquash        = $RootSquash.IsPresent
        insecure          = $Insecure.IsPresent
    }
}