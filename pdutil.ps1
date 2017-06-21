param(
    [Parameter(Mandatory=$false,Position=1)][string]$CMD,
    [Parameter(Mandatory=$false)][switch]$INCLUDE_JSP,
    [Parameter(Mandatory=$false)][switch]$INCLUDE_PHP,
    [Parameter(Mandatory=$false)][switch]$EXCLUDE_PAS,
    [Parameter(Mandatory=$false)][switch]$EXCLUDE_SERVER
)

# .\pdutil.ps1 Install
Function Install {
    # Enter temporary directory
    Set-Location (New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + ([System.IO.Path]::GetRandomFileName())).Split(".")[0])

    # Download
    Download

    # Chocolatey
    If (!(Test-Path "C:\ProgramData\Chocolatey")) {
        Write-Output "Chocolatey not found."
        Exit 1
    }

    # Install
    If (!($EXCLUDE_PAS)) {
        Write-Output "Resolving dependencies..."
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerRole"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-CommonHttpFeatures"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpErrors"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ApplicationDevelopment"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-NetFxExtensibility45"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HealthAndDiagnostics"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpLogging"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-Security"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-RequestFiltering"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-Performance"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerManagementTools"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-StaticContent"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-DefaultDocument"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-DirectoryBrowsing"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ASPNET45" -All
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ISAPIExtensions"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ISAPIFilter"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpCompressionStatic"
        Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ManagementConsole"
        Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4Extended-ASPNET45"
    }

    # Get credentials here.
    $USER=$ENV:USERDOMAIN + "\" + $ENV:USERNAME
    $C = Get-Credential -Message "Enter you Username and Password." -UserName $USER

    If (!($EXCLUDE_SERVER)) {
        Write-Output "Installing PrizmDoc Server..."
        $ARGLIST="-s -l server_log.out ServiceUser="+$C.UserName+" ServicePassword="+$C.GetNetworkCredential().Password
        $INSTALLER=(Start-Process ".\PrizmDocServer.exe" -ArgumentList $ARGLIST -PassThru)
        $INSTALLER.WaitForExit()

        If ($INSTALLER.ExitCode -ne 0) {
            Write-Output "Error installing server..."
        }
        Else {
            Write-Output "Restarting services..."
            Restart-Service Prizm

            If ((Get-Service Prizm).Status -ne "Running") {
                Write-Output "Unable to restart service 'Prizm'..."
            }

            If ($INCLUDE_PHP) {
                Write-Output "Installing apache..."
                choco install apache-httpd

                Write-Output "Installing php..."
                choco install php

                Write-Output "Restarting apache2..."
                Restart-Service Apache
            }

            If ($INCLUDE_JSP) {
                Write-Output "Installing java..."
                choco install jre8

                Write-Output "Installing tomcat7..."
                choco install tomcat

                Write-Output "Deploying PCCSample.war..."
                Copy-Item "C:\Prizm\Samples\jsp\target\PCCSample.war" "C:\Program Files\Tomcat\webapps"

                Write-Output "Restarting tomcat..."
                Restart-Service Tomcat
            }

            Write-Output "PrizmDoc Server successfully installed..."
        }
    }

    If (!($EXCLUDE_PAS)) {
        Write-Output "Installing PrizmDoc Client..."
        $ARGLIST="-s -l client_log.out ServiceUser="+$C.UserName+" ServicePassword="+$C.GetNetworkCredential().Password
        $INSTALLER=(Start-Process ".\PrizmDocClient.exe" -ArgumentList $ARGLIST -PassThru)
        $INSTALLER.WaitForExit()

        If ($INSTALLER.ExitCode -ne 0) {
            Write-Output "Error installing client..."
        }
        Else {
            # License
            License

            Write-Output "Restarting PAS..."
            Restart-Service PrizmApplicationServices

            Write-Output "Restarting samples..."
            Restart-Service PrizmDemo

            Write-Output "Starting samples..."

            Start-Process -FilePath "http://localhost:18681/admin"
            Start-Process -FilePath "http://localhost:18681/PCCIS/V1/Static/Viewer/Test"

            If ($INCLUDE_PHP) {
                Start-Process -FilePath "http://localhost/pccis_sample/splash"
            }
            If ($INCLUDE_JSP) {
                Start-Process -FilePath "http://localhost:8080/PCCSample"
            }
        }
    }
}

# .\pdutil.ps1 Remove
Function Remove {
    If (Test-Path "C:\Prizm") {
        # Prompt for confirmation
        $RESPONSE = Read-Host -Prompt "Prior installation detected. Remove? [y/N] "
        If (!($RESPONSE  -match "^([yY][eE][sS]|[yY])$")) {
            Write-Output "Terminating."
            Exit 1
        }

        Write-Output "Stopping services..."
        Stop-Service Prizm

        Write-Output "Stopping PAS..."
        Stop-Service PrizmApplicationServices

        Write-Output "Stopping samples..."
        Stop-Service PrizmDemo

        Write-Output "Removing remaining files..."
        Remove-Item -Recurse -Force "C:\Prizm"

        Write-Output "Successfully removed."
    } Else {
        Write-Output "No prior installation detected. Terminating."
    }
}

# .\pdutil.ps1 Download
Function Download {
    $SOURCE=(Invoke-WebRequest -Uri "https://www.accusoft.com/products/prizmdoc/eval/" -Method Get -UseBasicParsing).Content

    $SERVER_LATEST=($SOURCE | Select-String -Pattern "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*server[a-zA-Z0-9./?=_-]*.exe").Matches[0].Value
    $CLIENT_LATEST=($SOURCE | Select-String -Pattern "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*client[a-zA-Z0-9./?=_-]*.exe").Matches[0].Value

    If (!($EXCLUDE_SERVER)) {
        Write-Output "Downloading Server..."
        Invoke-WebRequest -Uri $SERVER_LATEST -Method Get -UseBasicParsing -OutFile "PrizmDocServer.exe"
    }

    If (!($EXCLUDE_PAS)) {
        Write-Output "Downloading Client..."
        Invoke-WebRequest -Uri $CLIENT_LATEST -Method Get -UseBasicParsing -OutFile "PrizmDocClient.exe"
    }
}

# .\pdutil.ps1 License
Function License {
    If (Test-Path C:\Prizm) {
        while ($true) {
            Write-Output "  1.) I would like to license this system with an OEM LICENSE."
            Write-Output "  2.) I would like to license this system with a NODE-LOCKED LICENSE."
            Write-Output "  3.) I have a license but I do not know what type."
            Write-Output "  4.) I do not have a license but I would like an EVALUATION."
            Write-Output "  5.) I do not want to license my product at this time."
            Write-Output ""

            $RESPONSE = 1
            $RESPONSE = Read-Host -Prompt "Select an option (1-5) [1]: "
            Switch ($RESPONSE) {
                "1" {
                    $SOLUTION_NAME = Read-Host -Prompt "Solution name: "
                    $OEM_KEY = Read-Host -Prompt "OEM key: "

                    Write-Output "Licensing..."
                    If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy write "$SOLUTION_NAME" "$OEM_KEY")") {
                        Write-Output "Licensing failed. Terminating."
                        Exit 1
                    }
                    break
                }
                "2" {
                    $SOLUTION_NAME = Read-Host -Prompt "Solution name: "
                    $CONFIG_FILE = Read-Host -Prompt "Configuration file path (relative to $PWD): "
                    $ACCESS_KEY = Read-Host -Prompt "Access key: "

                    Write-Output "Licensing..."
                    If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy get "$CONFIG_FILE" "$SOLUTION_NAME" "$ACCESS_KEY")") {
                        Write-Output "Licensing failed. Terminating."
                        Exit 1
                    }
                    break
                }
                "3" {
                    Write-Output ""
                    Write-Output "  You can find your license type by selecting the \"Licenses\" tab on the"
                    Write-Output "Accusoft Portal: https://my.accusoft.com/"
                    Write-Output ""
                    Write-Output "  For an OEM LICENSE, you will be provided with a SOLUTION NAME and an OEM KEY."
                    Write-Output ""
                    Write-Output "  For a NODE-LOCKED LICENSE, you will be provided with a SOLUTION NAME, a"
                    Write-Output "CONFIGUATION FILE, and an ACCESS KEY."
                    Write-Output ""
                    Write-Output "  If you have not spoken with a member of the Accusoft Sales department, it is"
                    Write-Output "likely that you are interested in an EVALUATION."
                    Write-Output ""
                    Write-Output "  If you require additional assistance, please contact sales@accusoft.com."
                    Write-Output ""
                    break
                }
                "4" {
                    $EMAIL = Read-Host -Prompt "Email address: "

                    If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar eval get "$EMAIL")") {
                        Write-Output "Licensing failed. Terminating."
                        Exit 1
                    }
                    break
                }
                "5" {
                    Write-Output "Terminating."
                    Exit 1
                    break
                }
                * {
                    $RESPONSE = Read-Host -Prompt "Token \`$TOKEN\` unrecognized. Continue? [y/N] "
                    If (!($RESPONSE  -match "^([yY][eE][sS]|[yY])$")) {
                        Write-Output "Terminating."
                        Exit 1
                    }
                    break
                }
            }
        }
    } Else {
        Write-Output "PrizmDoc is not installed. Terminating."
        Exit 1
    }
}

# .\pdutil.ps1 Clear-Logs
Function Clear-Logs {
    # Prompt for confirmation
    $RESPONSE = Read-Host -Prompt "Clear logs? [y/N] "
    If (!($RESPONSE  -match "^([yY][eE][sS]|[yY])$")) {
        Write-Output "Terminating."
        Exit 1
    }

    Write-Output "Stopping services..."
    Stop-Service Prizm

    Write-Output "Removing logs..."
    Remove-Item -Recurse -Force "C:\Prizm\logs\*"
    New-Item -ItemType Directory -Path "C:\Prizm\logs\pas"

    Write-Output "Starting services..."
    Start-Service PrizmApplicationServices

    Write-Output "Successfully removed."
}

# .\pdutil.ps1 Help
Function PrintHelp {
    Write-Output "Usage:"
    Write-Output "  @powershell -NoProfile -ExecutionPolicy Bypass -File .\pdutil.ps1 (Command) [Options]"
    Write-Output ""
    Write-Output "Reduces common PrizmDoc maintenance tasks down to proper Linux one-liners."
    Write-Output ""
    Write-Output "Commands:"
    Write-Output "  Install - Installs PrizmDoc"
    Write-Output "  Remove - Removes prior PrizmDoc installation"
    Write-Output "  Download - Downloads PrizmDoc"
    Write-Output "  License - Licenses PrizmDoc"
    Write-Output "  Clear-Logs - Clears the PrizmDoc log files"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -IncludePHP     Include PHP Samples"
    Write-Output "  -IncludeJSP     Include JSP Samples"
    Write-Output "  -IncludeNET     Include .NET Framework Samples"
    Write-Output "  -ExcludePAS     Exclude PAS"
    Write-Output "  -ExcludeServer  Exclude PrizmDoc Server"
}

# .\pdutil.ps1 *
Function Main {
    Write-Output ""
    Write-Output "PrizmDoc Utility v1.0"
    Write-Output ""

    # Check privileges
    If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Insufficient privileges. Terminating."
        Exit 1
    }

    # Check architecture
    If (!([Environment]::Is64BitOperatingSystem)) {
        Write-Output "Incompatible architecture. Terminating."
        Exit 1
    }

    # Save current working directory
    $CWD = Get-Location

    Switch ($CMD) {
        "Install" {
            Install
            break
        }
        "Remove" {
            Remove
            break
        }
        "Download" {
            Download
            break
        }
        "License" {
            License
            break
        }
        "Clear-Logs" {
            Clear-Logs
            break
        }
        default {
            Write-Output "Unrecognized Option: $CMD"
            Write-Output ""
            PrintHelp
        }
        "Help" {
            PrintHelp
            break
        }
    }

    # Restore current working directory
    Set-Location $CWD

    Exit 0
}

Main
