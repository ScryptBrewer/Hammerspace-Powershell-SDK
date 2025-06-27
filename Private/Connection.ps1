# Private/Connection.ps1
# Contains functions for initializing the connection and handling login.
New-Variable -Name HammerspaceSession -Value $null -Scope Script

function Initialize-HammerspaceConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cluster,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 8443,
        
        [Parameter(Mandatory = $false)]
        [bool]$VerifySSL = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 60
    )
    
    # Handle SSL Certificate Validation Based on PowerShell Version
    if (-not $VerifySSL) {
        Write-Warning "SSL certificate verification is disabled. This is not recommended for production environments."
        
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            # This is the older, PowerShell 5.1 method. It affects the entire session.
            Write-Verbose "Applying PowerShell 5.1 method for skipping certificate validation."
            
            $certValidationCode = @"
            using System.Net;
            using System.Net.Security;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint,
                    X509Certificate certificate,
                    WebRequest request,
                    int certificateProblem) {
                    return true;
                }
            }
"@
            Add-Type -TypeDefinition $certValidationCode -Language CSharp
            [System.Net.ServicePointManager]::CertificatePolicy = [TrustAllCertsPolicy]::new()
        }
    }

    # Initialize the session state object, stored globally within the script module's scope.
    $script:HammerspaceSession = @{
        Cluster     = $Cluster
        Port        = $Port
        BaseUrl     = "https://{0}:{1}/mgmt/v1.2/rest/" -f $Cluster, $Port
        LoginUrl    = "https://{0}:{1}/mgmt/v1.2/rest/login" -f $Cluster, $Port
        VerifySSL   = $VerifySSL
        Timeout     = $Timeout
        Username    = if ($Credential) { $Credential.UserName } else { $null }
        Password    = if ($Credential) { $Credential.GetNetworkCredential().Password } else { $null }
        Session     = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        IsLoggedIn  = $false
    }

    Write-Verbose "Hammerspace session initialized for cluster '$Cluster'."
}

function Invoke-HammerspaceLogin {
    [CmdletBinding()]
    param()

    Write-Verbose "Attempting to log in as '$($script:HammerspaceSession.Username)'."
    
    $loginPayload = @{
        username = $script:HammerspaceSession.Username
        password = $script:HammerspaceSession.Password
    }

    try {
        Invoke-HammerspaceRestCall -Path $script:HammerspaceSession.LoginUrl -Method 'POST' -BodyData $loginPayload -BodyFormat 'Form' -IsLogin $true -IsAbsoluteUrl $true
        $script:HammerspaceSession.IsLoggedIn = $true
        Write-Verbose "Login successful."
    }
    catch {
        $script:HammerspaceSession.IsLoggedIn = $false
        throw "Login failed for user '$($script:HammerspaceSession.Username)'. Error: $($_.Exception.Message)"
    }
}