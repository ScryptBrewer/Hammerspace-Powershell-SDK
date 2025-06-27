# Public/New-HammerspaceShare.ps1
# Contains the function for creating a new Hammerspace share.

function New-HammerspaceShare {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Default')]
    [OutputType([psobject])]
    param(
        # Parameter Set 1: Default (Individual Parameters)
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Default')]
        [string]$Name,

        # --- CHANGE 1: Made the Path parameter OPTIONAL ---
        [Parameter(Mandatory=$false, Position=1, ParameterSetName='Default')]
        [string]$Path,

        [Parameter(ParameterSetName='Default')]
        [string]$Comment,

        [Parameter(ParameterSetName='Default')]
        [hashtable[]]$ExportOptions,

        [Parameter(ParameterSetName='Default')]
        [hashtable[]]$ShareObjectives,

        [Parameter(ParameterSetName='Default')]
        [long]$ShareSizeLimit,

        [Parameter(ParameterSetName='Default')]
        [int]$WarnUtilizationPercentThreshold,

        [Parameter(ParameterSetName='Default')]
        [switch]$SmbBrowsable,

        # Parameter Set 2: ByDataHashtable
        [Parameter(Mandatory=$true, ParameterSetName='ByDataHashtable', ValueFromPipeline=$true)]
        [hashtable]$ShareData,

        # Common Parameters for all sets
        [Parameter()]
        [switch]$MonitorTask,

        [Parameter()]
        [int]$Timeout = 300
    )

    begin {
        $body = $null
    }

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Default' -and -not $PSBoundParameters.ContainsKey('Path')) {
                $Path = "/$Name"
                Write-Verbose "Path parameter not provided. Defaulting path to '$Path'."
            }

            switch ($PSCmdlet.ParameterSetName) {
                'ByDataHashtable' {
                    $body = $ShareData
                }
                'Default' {
                    # Build the body from individual parameters
                    $body = @{}
                    $body.name = $Name
                    $body.path = $Path # This will now use either the user-provided path or the default one
                    if ($PSBoundParameters.ContainsKey('Comment')) { $body.comment = $Comment }
                    if ($PSBoundParameters.ContainsKey('ExportOptions')) { $body.exportOptions = $ExportOptions }
                    if ($PSBoundParameters.ContainsKey('ShareObjectives')) { $body.shareObjectives = $ShareObjectives }
                    if ($PSBoundParameters.ContainsKey('ShareSizeLimit')) { $body.shareSizeLimit = $ShareSizeLimit }
                    if ($PSBoundParameters.ContainsKey('WarnUtilizationPercentThreshold')) { $body.warnUtilizationPercentThreshold = $WarnUtilizationPercentThreshold }
                    if ($PSBoundParameters.ContainsKey('SmbBrowsable')) { $body.smbBrowsable = $SmbBrowsable.IsPresent }
                }
            }

            if ($pscmdlet.ShouldProcess($body.name, "Create Share (Path: $($body.path))")) {
                Write-Verbose "Submitting POST request to create share '$($body.name)'"
                if ($MonitorTask) {
                    Invoke-HammerspaceTaskMonitor -ResourcePath 'shares' -Method 'POST' -Data $body -Timeout $Timeout
                } else {
                    Invoke-HammerspaceRestCall -Path 'shares' -Method 'POST' -BodyData $body
                }
            }
        }
        catch {
            Write-Error "Failed to create Hammerspace share. Error: $_"
        }
    }
}