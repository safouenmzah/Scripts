#!/bin/bash

# ./pdutil.sh install
function install() {
	# Check architecture
	if [[ "$(uname -m)" != "x86_64" ]]; then
        echo "Incompatible architecture. Terminating."
        exit 1
    fi

	# Enter temporary directory
	cd "$(mktemp -d)" || (echo "Directory change failed. Terminating" && exit 1)

	# Download
    download
	
	# Install Apache
	apt-get install -y apache2 &> /dev/null

	echo "Extracting archives..."
	if [[ ! "$(find . -name "*.tar.gz" -exec tar -xzvf {} \;)" ]]; then 
		echo "Extraction failed. Terminating."
		exit 1
	fi

	echo "Resolving dependencies..."
	dpkg --force-depends -i ./*server*/*.deb
	dpkg --force-depends -i ./*client*/*.deb

	echo "Installing PrizmDoc..."
	if [[ ! "$(apt-get -fy install)" ]]; then
		echo "Installation failed. Terminating."
		exit 1
	fi

	echo "Starting services..."
	/usr/share/prizm/scripts/pccis.sh start

	echo "Starting PAS..."
	/usr/share/prizm/pas/pm2/pas.sh start

	echo "Restarting apache2..."
	if [[ ! "$(apachectl restart &> /dev/null)" ]]; then
		service apache2 restart
	fi

	echo "Starting samples..."
	firefox "localhost:18681/admin" "http://localhost:18681/PCCIS/V1/Static/Viewer/Test" &> /dev/null &

	echo "Successfully installed."
}

# ./pdutil.sh remove
function remove() {
	if [[ -d "/usr/share/prizm" ]]; then

  		# Prompt for confirmation
		read -rp "Prior installation detected. Remove? [y/N] " RESPONSE
		if [[ $RESPONSE == "^([yY][eE][sS] | [yY])$" ]]; then
        	echo "Terminating."
        	exit 1
		fi

  		echo "Stopping services..."
  		/usr/share/prizm/scripts/pccis.sh stop

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

	echo "Downloading Server..."
	wget "$SERVER_LATEST"

	echo "Downloading Client..."
	wget "$CLIENT_LATEST"

	echo "Successfully downloaded."
}

# ./pdutil.sh license
function license() {
	if [[ -d "$(/usr/share/prizm 2>/dev/null)" ]]; then
		read -rp "Solution name? " SOLUTION_NAME
		read -rp "OEM key?" OEM_KEY

		echo "Licencing..."
		if [ ! "$(/usr/share/prizm/java/jre6-linux-x86-64/bin/java -jar plu/plu.jar deploy write "$SOLUTION_NAME" "$OEM_KEY")" ]; then
			echo "Licensing failed. Terminating."
			exit 1
		fi
	else
		echo "PrizmDoc is not installed. Terminating."
	fi
}

# ./pdutil.sh clearlogs
function clearlogs() {
	# Prompt for confirmation
	read -rp "Clear logs? [y/N] " RESPONSE
	if [[ $RESPONSE == "^([yY][eE][sS] | [yY])$" ]]; then
    	echo "Terminating."
    	exit 1
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

	# Check privilages
	if [ "$(/usr/bin/id -u)" != 0 ]; then
    	echo "Insufficient privilages. Terminating."
    	exit 1
	fi

	CWD=$(pwd)

	case $1 in
	"install")
		install "$2"
		;;
	"remove")
		remove
		;;
	"download")
		download
		;;
	"license")
		license
		;;
	"clearlogs")
		clearlogs
		;;
	*)
		echo "Usage: ./pdutil.sh (install|remove|download|license|clearlogs)"
		;;
	esac

	cd "$CWD" || (echo "Directory change failed. Terminating" && exit 1)

	exit 0
}

main "$1"
