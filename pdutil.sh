#!/bin/bash

# ./pdutil.sh install
function install() {
	# Enter temporary directory
	cd "$(mktemp -d)" || (echo "Directory change failed. Terminating." && exit 1)

	# Download
	download

	echo "Extracting archives..."
	if [[ ! "$(find . -name "*.tar.gz" -exec tar -xzvf {} \;)" ]]; then 
		echo "Extraction failed. Terminating." && exit 1
	fi

	echo "Resolving dependencies..."
	if [[ ! "$EXCLUDE_SERVER" == true ]]; then
		dpkg --force-depends -i ./*server*/*.deb
	fi

	if [[ ! "$EXCLUDE_PAS" == true ]]; then
		dpkg --force-depends -i ./*client*/*.deb
	fi

	echo "Installing PrizmDoc..."
	if [[ ! "$(apt-get -fy install)" ]]; then
		echo "Installation failed. Terminating." && exit 1
	fi

	if [[ ! "$EXCLUDE_SERVER" == true ]]; then
		echo "Restarting services..."
		/usr/share/prizm/scripts/pccis.sh restart
	fi

	echo "Successfully installed."
	if [[ ! "$EXCLUDE_PAS" == true ]]; then
		if [[ "$INCLUDE_PHP" == true ]]; then
			echo "Installing apache2..."
			apt-get install -y apache2 &> /dev/null

			echo "Installing php5..."
			apt-get install -y php5 libapache2-mod-php5

			sed -i "176iAlias /pccis_sample /usr/share/prizm/Samples/php\n<Directory /usr/share/prizm/Samples/php>\n\tAllowOverride All\n\tRequire all granted\n</Directory>" /etc/apache2/apache2.conf
			
			echo "Restarting apache2..."
			apachectl restart
		fi

		if [[ "$INCLUDE_JSP" == true ]]; then
			echo "Installing java..."
			apt-get install -y default-jre

			echo "Installing tomcat7..."
			apt-get install -y tomcat7

			echo "Deploying PCCSample.war..."
			cp /usr/share/prizm/Samples/jsp/target/PCCSample.war /var/lib/tomcat7/webapps/

			echo "Restarting tomcat..."
			service tomcat7 restart
		fi

		echo "Restarting PAS..."
		/usr/share/prizm/pas/pm2/pas.sh restart

		echo "Restarting samples..."
		/usr/share/prizm/scripts/demos.sh restart

		echo "Starting samples..."
		firefox "localhost:18681/admin" "http://localhost:18681/PCCIS/V1/Static/Viewer/Test" "$([[ "$INCLUDE_PHP" == true ]] && "localhost/pccis_sample/splash")" "$([[ "$INCLUDE_JSP" == true ]] &&"localhost:8080/PCCSample")" &> /dev/null &
	fi
}

# ./pdutil.sh remove
function remove() {
	if [[ -d "/usr/share/prizm" ]]; then

		# Prompt for confirmation
		read -rp "Prior installation detected. Remove? [y/N] " RESPONSE
		if [[ ! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo "Terminating." && exit 1
		fi

		echo "Stopping services..."
		/usr/share/prizm/scripts/pccis.sh stop &> /dev/null

		echo "Stopping PAS..."
		/usr/share/prizm/pas/pm2/pas.sh stop &> /dev/null

		echo "Stopping samples..."
		/usr/share/prizm/scripts/demos.sh stop &> /dev/null

		echo "Removing dependencies..."
		apt-get -fy remove prizm-services.* &> /dev/null

		echo "Removing remaining files..."
		rm -rf /usr/share/prizm

		echo "Successfully removed."
	else
		echo "No prior installation detected. Terminating."
	fi
}

# ./pdutil.sh download
function download() {
	SOURCE="$(wget -qO- https://www.accusoft.com/products/prizmdoc/eval/)"

	SERVER_LATEST="$(echo "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*server[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"
	CLIENT_LATEST="$(echo "$SOURCE" | grep -Eio "http://products.accusoft.com/[a-zA-Z0-9./?=_-]*client[a-zA-Z0-9./?=_-]*.deb.tar.gz" | uniq | sort --reverse | head -n1)"

	if [[ ! "$EXCLUDE_SERVER" == true ]]; then
		echo "Downloading Server..."
		wget "$SERVER_LATEST"
	fi

	if [[ ! "$EXCLUDE_PAS" == true ]]; then
		echo "Downloading Client..."
		wget "$CLIENT_LATEST"
	fi
}

# ./pdutil.sh license
function license() {
	if [[ -d "$(/usr/share/prizm &> /dev/null)" ]]; then
		read -rp "Solution name: " SOLUTION_NAME
		read -rp "OEM key (leave blank for node-locked): " OEM_KEY

		echo "Licencing..."
		if [ ! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy write "$SOLUTION_NAME" "$OEM_KEY")" ]; then
			echo "Licensing failed. Terminating." && exit 1
		fi
	else
		echo "PrizmDoc is not installed. Terminating." && exit 1
	fi
}

# ./pdutil.sh clearlogs
function clearlogs() {
	# Prompt for confirmation
	read -rp "Clear logs? [y/N] " RESPONSE
	if [[ "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo "Terminating." && exit 1
	fi

	echo "Stopping services..."
	/usr/share/prizm/scripts/pccis.sh stop

	echo "Removing logs..."
	rm -rf /usr/share/prizm/logs/*
	mkdir /usr/share/prizm/logs/pas

	echo "Starting services..."
	/usr/share/prizm/scripts/pccis.sh start

	echo "Successfully removed."
}

# ./pdutil.sh *
function main() {
	echo ""
	echo "PrizmDoc Utility v1.0"
	echo ""

	DEB_BASED=false
	RPM_BASED=false
	NIX_BASED=false

	INCLUDE_PHP=false
	INCLUDE_JSP=false
	EXCLUDE_PAS=false
	EXCLUDE_SERVER=false

	# Check privilages
	if [[ "$(/usr/bin/id -u)" != 0 ]]; then
		echo "Insufficient privilages. Terminating." && exit 1
	fi

	# Check architecture
	if [[ "$(uname -m)" != "x86_64" ]]; then
		echo "Incompatible architecture. Terminating." && exit 1
	fi

	# Save current working directory
	CWD=$(pwd)

	# Detect operating system
	if [[ -f "/usr/bin/apt-get" ]]; then
		DEB_BASED=true
		echo "Debian-based operating system detected. Proceeding."
	elif [[ -f "/usr/bin/yum" ]]; then
		RPM_BASED=true
		echo "RPM-based operating system detected."
		echo "Not yet implemented. Terminating." && exit 1
	else
		NIX_BASED=true
		echo "Generic *nix-based operating system detected."
		echo "Not yet implemented. Terminating." && exit 1
	fi

	case $1 in
	"install")
		for TOKEN in "${@:2}"; do
			case "$TOKEN" in
			"--include-php")
				INCLUDE_PHP=true
				;;
			"--include-jsp")
				INCLUDE_JSP=true
				;;
			"--exclude-pas")
				EXCLUDE_PAS=true
				;;
			"--exclude-server")
				EXCLUDE_SERVER=true
				;;
			*)
				read -rp "Token \`$TOKEN\` unrecognized. Continue? [y/N] " RESPONSE
				if [[ ! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$ ]]; then
					echo "Terminating." && exit 1
				fi
			esac
		done

		install
		;;
	"remove")
		remove
		;;
	"download")
		for TOKEN in "${@:2}"; do
			case "$TOKEN" in
			"--exclude-pas")
				EXCLUDE_PAS=true
				;;
			"--exclude-server")
				EXCLUDE_SERVER=true
				;;
			*)
				read -rp "Token \`$TOKEN\` unrecognized. Continue? [y/N] " RESPONSE
				if [[ ! "$RESPONSE"  =~ ^([yY][eE][sS]|[yY])$ ]]; then
					echo "Terminating." && exit 1
				fi
			esac
		done

		download
		;;
	"license")
		license
		;;
	"clearlogs")
		clearlogs
		;;
	*)
		echo "Usage:"
		echo "  ./pdutil.sh (install|remove|download|license|clearlogs) [options]"
		echo ""
		echo "Reduces common PrizmDoc maintenance tasks down to proper Linux one-liners."
		echo ""
		echo "Commands:"
		echo "  install - Installs PrizmDoc"
		echo "  remove - Removes prior PrizmDoc installation"
		echo "  download - Downloads PrizmDoc"
		echo "  license - Licenses PrizmDoc"
		echo "  clearlogs - Clears the PrizmDoc log files"
		echo ""
		echo "Options:"
		echo "  --include-php     Include PHP Samples"
		echo "  --include-jsp     Include JSP Samples"
		echo "  --exclude-pas     Exclude PAS"
		echo "  --exclude-server  Exclude PrizmDoc Server"
		;;
	esac

	# Restore current working directory
	cd "$CWD" || (echo "Directory change failed. Terminating." && exit 1)

	exit 0
}

main "$@"
