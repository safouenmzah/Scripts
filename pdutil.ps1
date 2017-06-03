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
        Enable-WindowsOptionalFeature -FeatureName "IIS-WebServerRole"
        Enable-WindowsOptionalFeature -FeatureName "IIS-WebServer"
        Enable-WindowsOptionalFeature -FeatureName "IIS-CommonHttpFeatures"
        Enable-WindowsOptionalFeature -FeatureName "IIS-HttpErrors"
        Enable-WindowsOptionalFeature -FeatureName "IIS-ApplicationDevelopment"
        Enable-WindowsOptionalFeature -FeatureName "IIS-NetFxExtensibility45"
        Enable-WindowsOptionalFeature -FeatureName "IIS-HealthAndDiagnostics"
        Enable-WindowsOptionalFeature -FeatureName "IIS-HttpLogging"
        Enable-WindowsOptionalFeature -FeatureName "IIS-Security"
        Enable-WindowsOptionalFeature -FeatureName "IIS-RequestFiltering"
        Enable-WindowsOptionalFeature -FeatureName "IIS-Performance"
        Enable-WindowsOptionalFeature -FeatureName "IIS-WebServerManagementTools"
        Enable-WindowsOptionalFeature -FeatureName "IIS-StaticContent"
        Enable-WindowsOptionalFeature -FeatureName "IIS-DefaultDocument"
        Enable-WindowsOptionalFeature -FeatureName "IIS-DirectoryBrowsing"
        Enable-WindowsOptionalFeature -FeatureName "IIS-ASPNET45"
        Enable-WindowsOptionalFeature -FeatureName "IIS-ISAPIExtensions"
        Enable-WindowsOptionalFeature -FeatureName "IIS-ISAPIFilter"
        Enable-WindowsOptionalFeature -FeatureName "IIS-HttpCompressionStatic"
        Enable-WindowsOptionalFeature -FeatureName "IIS-ManagementConsole"
        Enable-WindowsOptionalFeature -FeatureName "NetFx4Extended-ASPNET45"
    }

    Write-Output "Installing PrizmDoc..."
    If (!($EXCLUDE_SERVER)) {
        PrizmDocServer.exe ServiceUser=DOMAIN.TLD\USERNAME ServicePassword=PASSWORD -s
    }

    If (!($EXCLUDE_PAS)) {
        PrizmDocClient.exe ServiceUser=DOMAIN.TLD\USERNAME ServicePassword=PASSWORD -s
    }

    If (!($EXCLUDE_SERVER)) {
        Write-Output "Restarting services..."
        Restart-Service Prizm
    }

    Write-Output "Successfully installed."
    If (!($EXCLUDE_PAS)) {
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
    }

    Write-Output "Successfully installed."
    If (!($EXCLUDE_PAS)) {
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
    $SOURCE="$(curl -s https://www.accusoft.com/products/prizmdoc/eval/)"

    $SERVER_LATEST="$(Write-Output "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*server[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"
    $CLIENT_LATEST="$(Write-Output "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*client[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"

    If (!($EXCLUDE_SERVER)) {
        Write-Output "Downloading Server..."
        curl -O "$SERVER_LATEST"
    }

    If (!($EXCLUDE_PAS)) {
        Write-Output "Downloading Client..."
        curl -O "$CLIENT_LATEST"
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

# .\pdutil.ps1 *
Function Main {
    Write-Output ""
    Write-Output "PrizmDoc Utility v1.0"
    Write-Output ""

    $INCLUDE_PHP = $false
    $INCLUDE_JSP = $false
    $EXCLUDE_PAS = $false
    $EXCLUDE_SERVER = $false

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

    Switch ($args[0]) {
        "Install" {
            ForEach ($arg in $args) {
                Switch ($TOKEN) {
                    "-IncludePHP" {
                        $INCLUDE_PHP = $true
                    }
                    "-IncludeJSP" {
                        $INCLUDE_JSP = $true
                    }
                    "-ExcludePAS" {
                        $EXCLUDE_PAS = $true
                    }
                    "-ExcludeServer" {
                        $EXCLUDE_SERVER = $true
                    }
                    default {
                        $RESPONSE = Read-Host -Prompt "Token \`$TOKEN\` unrecognized. Continue? [y/N] " 
                        If (!($RESPONSE  -match "^([yY][eE][sS]|[yY])$")) {
                            Write-Output "Terminating."
                            Exit 1
                        }
                    }
                }
            }

            Install
            break
        }
        "Remove" {
            Remove
            break
        }
        "Download" {
            ForEach ($arg in $args) {
                Switch ($TOKEN) {
                    "-ExcludePAS" {
                        $EXCLUDE_PAS=true
                        break
                    }
                    "-ExcludeServer" {
                        $EXCLUDE_SERVER=true
                        break
                    }
                    default {
                        $RESPONSE = Read-Host -Prompt "Token `$TOKEN` unrecognized. Continue? [y/N] " 
                        If (!($RESPONSE  -match "^([yY][eE][sS]|[yY])$")) {
                            Write-Output "Terminating."
                            Exit 1
                        }
                        break
                    }
                }
            }

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
            break
        }
    }

    # Restore current working directory
    Set-Location $CWD

    Exit 0
}

Main $args
