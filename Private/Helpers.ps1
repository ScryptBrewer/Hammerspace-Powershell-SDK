# Private/Helpers.ps1
# Contains helper functions for data conversion and other utilities.

# This function intelligently handles timestamps in seconds, milliseconds, or nanoseconds
# by inspecting the number of digits in the timestamp.
function Convert-HammerspaceTimeToDateTime {
    param(
        [Parameter(Mandatory=$true)]
        [long]$Timestamp
    )

    try {
        # Determine the unit based on the number of digits in the timestamp.
        $digitCount = $Timestamp.ToString().Length
        $seconds = 0

        if ($digitCount -le 11) {
            # Assumes SECONDS (e.g., 1749144534)
            Write-Verbose "Interpreting timestamp $Timestamp as SECONDS."
            $seconds = $Timestamp
        }
        elseif ($digitCount -le 14) {
            # Assumes MILLISECONDS (e.g., 1749144534933)
            Write-Verbose "Interpreting timestamp $Timestamp as MILLISECONDS."
            $seconds = [long]($Timestamp / 1000)
        }
        else {
            # Assumes NANOSECONDS (e.g., 1749144534933000)
            Write-Verbose "Interpreting timestamp $Timestamp as NANOSECONDS."
            $seconds = [long]($Timestamp / 1000000000)
        }

        # Create the epoch date in a cross-compatible way (works on PS 5.1 and 7+).
        $epoch = [System.DateTime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)

        # Add the calculated seconds to the epoch and convert to local time.
        return $epoch.AddSeconds($seconds).ToLocalTime()
    }
    catch {
        $errorMessage = @"
--------------------------------------------------
WARNING: Failed to convert timestamp.
  Input Value:       '$Timestamp'
  Exception Type:    $($_.Exception.GetType().FullName)
  Exception Message: $($_.Exception.Message)
--------------------------------------------------
"@
        Write-Warning $errorMessage
        return $null
    }
}