#!%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe

# ./pdutil.ps1 Install
Function Install {
	# Enter temporary directory
	cd "$(mktemp -d)"

	# Download
	Download

	# Install
	Write-Output "Resolving dependencies..."
	If (! $EXCLUDE_SERVER) {
		dpkg --force-depends -i ./*server*/*.deb
	}

	If (! "$EXCLUDE_PAS") {
		dpkg --force-depends -i ./*client*/*.deb
	}

	Write-Output "Installing PrizmDoc..."
	If (! $(apt-get -fy install)) {
		Write-Output "Installation failed. Terminating." -and Exit 1
	}

	If (! $EXCLUDE_SERVER) {
		Write-Output "Restarting services..."
		/usr/share/prizm/scripts/pccis.sh restart
	}

	Write-Output "Successfully installed."
	If (!($EXCLUDE_PAS)) {
		If ($INCLUDE_PHP) {
			Write-Output "Installing apache2..."
			apt-get install -y apache2

			Write-Output "Installing php5..."
			apt-get install -y php5 libapache2-mod-php5

			sed -i "176iAlias /pccis_sample /usr/share/prizm/Samples/php\n<Directory /usr/share/prizm/Samples/php>\n\tAllowOverride All\n\tRequire all granted\n</Directory>" /etc/apache2/apache2.conf
			
			Write-Output "Restarting apache2..."
			apachectl restart
		}

		If ($INCLUDE_JSP) {
			Write-Output "Installing java..."
			apt-get install -y default-jre

			Write-Output "Installing tomcat7..."
			apt-get install -y tomcat7

			Write-Output "Deploying PCCSample.war..."
			cp /usr/share/prizm/Samples/jsp/target/PCCSample.war /var/lib/tomcat7/webapps/

			Write-Output "Restarting tomcat..."
			service tomcat7 restart
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

# ./pdutil.ps1 Remove
Function Remove {
	If (-d "/usr/share/prizm") {
		# Prompt for confirmation
		$RESPONSE = Read-Host -Prompt "Prior installation detected. Remove? [y/N] " 
		If (! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$) {
			Write-Output "Terminating." -and Exit 1
		}

		Write-Output "Stopping services..."
		Stop-Service Prizm

		Write-Output "Stopping PAS..."
		Stop-Service PrizmApplicationServices

		Write-Output "Stopping samples..."
		Stop-Service PrizmDemo

		Write-Output "Removing dependencies..."
		apt-get -fy remove prizm-services.* &> /dev/null

		Write-Output "Removing remaining files..."
		rm -rf /usr/share/prizm

		Write-Output "Successfully removed."
	} Else {
		Write-Output "No prior installation detected. Terminating."
	}
}

# ./pdutil.ps1 Download
Function Download {
	$SOURCE="$(curl -s https://www.accusoft.com/products/prizmdoc/eval/)"

	$SERVER_LATEST="$(Write-Output "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*server[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"
	$CLIENT_LATEST="$(Write-Output "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*client[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"

	If (! "$EXCLUDE_SERVER") {
		Write-Output "Downloading Server..."
		curl -O "$SERVER_LATEST"
	}

	If (! "$EXCLUDE_PAS") {
		Write-Output "Downloading Client..."
		curl -O "$CLIENT_LATEST"
	}
}

# ./pdutil.ps1 License
Function License {
	If (-d "/usr/share/prizm") {
		while ($true) {
			Write-Output "  1.) I would like to license this system with an OEM LICENSE."
			Write-Output "  2.) I would like to license this system with a NODE-LOCKED LICENSE."
			Write-Output "  3.) I have a license but I do not know what type."
			Write-Output "  4.) I do not have a license but I would like an EVALUATION."
			Write-Output "  5.) I do not want to license my product at this time."
			Write-Output ""

			$RESPONSE=1
			$RESPONSE = Read-Host -Prompt "Select an option (1-5) [1]: " 
			Switch ("$RESPONSE") {
				"1" {
					$SOLUTION_NAME = Read-Host -Prompt "Solution name: " 
					$OEM_KEY = Read-Host -Prompt "OEM key: " 

					Write-Output "Licensing..."
					If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy write "$SOLUTION_NAME" "$OEM_KEY")") {
						Write-Output "Licensing failed. Terminating." -and Exit 1
					}
				}
				"2" {
					$SOLUTION_NAME = Read-Host -Prompt "Solution name: " 
					$CONFIG_FILE = Read-Host -Prompt "Configuration file path (relative to $PWD): " 
					$ACCESS_KEY = Read-Host -Prompt "Access key: " 

					Write-Output "Licensing..."
					If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy get "$CONFIG_FILE" "$SOLUTION_NAME" "$ACCESS_KEY")") {
						Write-Output "Licensing failed. Terminating." -and Exit 1
					}
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
				}
				"4" {
					$EMAIL = Read-Host -Prompt "Email address: " 

					If (! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar eval get "$EMAIL")") {
						Write-Output "Licensing failed. Terminating." -and Exit 1
					}
				}
				"5" {
					Write-Output "Terminating." -and Exit 1
				}
				* {
					$RESPONSE = Read-Host -Prompt "Token \`$TOKEN\` unrecognized. Continue? [y/N] " 
					If (! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$) {
						Write-Output "Terminating." -and Exit 1
					}
				}
			}
		}
	} Else {
		Write-Output "PrizmDoc is not installed. Terminating." -and Exit 1
	}
}

# ./pdutil.ps1 Clear-Logs
Function Clear-Logs {
	# Prompt for confirmation
	$RESPONSE = Read-Host -Prompt "Clear logs? [y/N] " 
	If (! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$) {
		Write-Output "Terminating." -and Exit 1
	}

	Write-Output "Stopping services..."
	/usr/share/prizm/scripts/pccis.sh stop

	Write-Output "Removing logs..."
	rm -rf /usr/share/prizm/logs/*
	mkdir /usr/share/prizm/logs/pas

	Write-Output "Starting services..."
	/usr/share/prizm/scripts/pccis.sh start

	Write-Output "Successfully removed."
}

# ./pdutil.ps1 *
Function Main {
	Write-Output ""
	Write-Output "PrizmDoc Utility v1.0"
	Write-Output ""

	$INCLUDE_PHP = false
	$INCLUDE_JSP = false
	$EXCLUDE_PAS = false
	$EXCLUDE_SERVER = false

	# Check privileges
	If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
		Write-Output "Insufficient privileges. Terminating." -and Exit 1
	}

	# Check architecture
	If (!([Environment]::Is64BitOperatingSystem)) {
		Write-Output "Incompatible architecture. Terminating." -and Exit 1
	}

	# Save current working directory
	$CWD = Get-Location

	Switch ($1) {
		"Install" {
			ForEach ("${@:2}") {
				Switch ("$TOKEN") {
					"--include-php" {
						$INCLUDE_PHP = $true
					}
					"--include-jsp" {
						$INCLUDE_JSP = $true
					}
					"--exclude-pas" {
						$EXCLUDE_PAS = $true
					}
					"--exclude-server" {
						$EXCLUDE_SERVER = $true
					}
					* {
						$RESPONSE = Read-Host -Prompt "Token \`$TOKEN\` unrecognized. Continue? [y/N] " 
						If (! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$) {
							Write-Output "Terminating." -and Exit 1
						}
					}
				}
			}

			Install
		}
		"Remove" {
			Remove
		}
		"Download" {
			ForEach ("${@:2}") {
				Switch ("$TOKEN") {
					"-ExcludePAS" {
						$EXCLUDE_PAS=true
					}
					"-ExcludeServer" {
						$EXCLUDE_SERVER=true
					}
					* {
						$RESPONSE = Read-Host -Prompt "Token \`$TOKEN\` unrecognized. Continue? [y/N] " 
						If (! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$) {
							Write-Output "Terminating." -and Exit 1
						}
					}
				}
			}

			Download
		}
		"License" {
			License
		}
		"Clear-Logs" {
			Clear-Logs
		}
		* {
			Write-Output "Usage:"
			Write-Output "  ./pdutil.ps1 (Install|Remove|Download|License|Clear-Logs) [Options]"
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
	}

	# Restore current working directory
	Set-Location $CWD

	Exit 0
}

Main $args
