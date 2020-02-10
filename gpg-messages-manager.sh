#!/bin/bash
#    ____             ____   ____
#   / ___|_ __  _   _|  _ \ / ___|
#  | |  _| '_ \| | | | |_) | |  _
#  | |_| | | | | |_| |  __/| |_| |
#   \____|_| |_|\__,_|_|    \____| Messages Manager
#
# Interactive application for encrypting
# and decrypting PGP messages efficiently.
# Dependencies : GnuPG, FZF

gpgDir=$HOME/Documents/pgp
editor=vim
fzf="fzf --height 30% --layout=reverse --border"

# Text format
bs=$(tput bold)
be=$(tput sgr0)

# Text color
red='\033[0;31m'
green='\033[0;32m'
end='\033[0m'

function checkDependencies() {
	dependencies=( gpg fzf $editor )
	ready=0

	for i in "${dependencies[@]}"; do
		which $i > /dev/null

		if [ $? -ne 0 ]; then
			ready=1
			break
		fi
	done

	if [ $ready -eq 0 ]; then
		checkDirectories
	else
		exit 1
	fi
}

function checkDirectories() {
 	cd $HOME

 	if [ ! -d Documents ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt,sig}

 	elif [ ! -d Documents/pgp ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt,sig}

 	elif [ ! -d Documents/pgp/asc ]; then
 			mkdir Documents/pgp/asc

 	elif [ ! -d Documents/pgp/pub ]; then
 			mkdir Documents/pgp/pub

 	elif [ ! -d Documents/pgp/txt ]; then
 			mkdir Documents/pgp/txt

	elif [ ! -d Documents/pgp/sig ]; then
		mkdir Documents/pgp/sig

 	else
 		echo "All OK."
 	fi

	checkAddr
}

function checkAddr() {
	cd $gpgDir
	if [ -f txt/adr.txt ]; then
		if [ $(du txt/adr.txt) -le 0 ]; then
			setAddr
		else
			showMenu
		fi
	else
		setAddr
	fi
}

function setAddr() {
	cd $gpgDir
	echo -e "You firstly need to specify your address."
	read -p "Press Enter to enter your address..." foo
	$editor txt/adr.txt
	checkAddr
}

function quit() {
	clear
	exit 0
}

function showMenu() {
	clear
	echo "${bs}Welcome to GnuPG !${be}"
	askOption
}

function askOption() {

	options=(
		"Show keyring"
		"Generate a new key pair"
		"Import a public key"
		"Export a public key"
		"Remove a public key"
		"Encrypt your address"
		"Encrypt a message"
		"Decrypt a message"
		"Sign a file"
		"Verify a file"
		"Exit"
	)

	choice=$(for (( i=0; i<${#options[*]}; i++ )); do
		echo "[${i}] ${options[${i}]}"
	done |
	$fzf |
	cut -d ' ' -f1 |
	grep -oE '([0-9]+)'
	)

	case $choice in
		0)
			showKeys "i";;
		1)
			genKey;;
		2)
			addPubKey;;
		3)
			exportPubKey;;
		4)
			delPubKey;;
		5)
			encryptMsg "adr";;
		6)
			encryptMsg;;
		7)
			decryptMsg;;
		8)
			signFile;;
		9)
			verifyFile;;
		10)
			quit;;
	esac
	clear
	askOption
}

function showKeys() {

	# Interactive mode
	if [ "$1" == "i" ]; then
		echo
	fi

	# Show private keys (email) only
	if [ "$1" == "private" ]; then
		listKeys="--list-secret-keys"
		index=2
	else
		listKeys="--list-keys"
		index=1
	fi

	# Show keyring
	gpg $listKeys |
		grep -E '^uid' |
		sed 's/^.\+\] //' |
		sed 's/>//' |
		sed 's/ </;/' |
		cut -d ';' -f ${index}- --output-delimiter=$'\t\t\t'

	if [ "$1" == "i" ]; then
		toMenu
	fi
}

function toMenu() {
	echo; read -p "Press Enter to continue..." foo
	showMenu
}

function selectKey() {
	showKeys | $fzf | cut -f4 -d $'\t'
}

function genKey() {

	gpgVersion=$(gpg --version | sed 1q | cut -d ' ' -f3)

	if [ $(echo -e "2.2.17\n${gpgVersion}" | sort -V | head -n1) == "2.2.17" ]; then

		# GPG version is greather than 2.2.17
		gpg --full-generate-key
	else

		# GPG version is lower than 2.2.17
		gpg --default-new-key-algo rsa4096 --gen-key
	fi

	toMenu
}

function returnText() {

	if [ $? -ne 0 ]; then

		# Generic error message
		text=(
			"\n"
			"${red}"
			"Warning: "
			"An error occured. "
			"Please refer to the gpg error log."
			"${end}"
		)

	else

		# Message on success
		text=(
			"\n"
			"${green}"
			"$@"
			"${end}"
		)
	fi

	# Print the whole text
	for i in "${text[@]}"; do
		echo -ne "$i"
	done
	echo

	# Clear cached passphrases
	echo 'RELOADAGENT' | gpg-connect-agent > /dev/null

	# Ask for opening decrypted message
	if [ ! "$1" == "Message successfully decrypted to" ]; then
		toMenu
	fi

}

function addPubKey() {

	cd $gpgDir
	echo "Please select a public key to import : "

	public=$(
		ls pub/ |
		head |
		$fzf
	)

	if [ ! -z $public ]; then

		gpg --batch --yes --import pub/$public

		returnText \
		 	"Public key " \
		 	"${public} " \
		 	"added !"

	fi

}

function delPubKey() {

	echo "Please select a public key to delete : "
	public=$(selectKey)

	# Check for gpg private keys
	privateKeys=($(showKeys 'private'))
	for email in "${privateKeys[@]}"; do

		if [ "$email" == "$public" ]; then

			# Selected key is a private one
			gpg --delete-secret-key $public
			break
		fi
	done

	gpg --batch --yes --delete-key $public

	# Check if deletion is successful
	if [ -z $(showKeys | grep "$public") ]; then

		returnText \
			"Public key " \
			"${public} " \
			"deleted !"

	fi

}

function encryptMsg() {

	cd $gpgDir
	echo "Please select a recipient : "
	recipient=$(selectKey)

	if [ ! -z $recipient ]; then

		if [ "$1" == "adr" ]; then
		# Encrypt address for recipient

			recipientFormat=$(
				echo -n 'adr_for_';
				echo $recipient |
				sed 's/@.\+$//'
			)

			gpg \
				--trust-model always \
				--armor \
				--encrypt \
				--recipient $recipient \
				txt/adr.txt

			mv txt/adr.txt.asc asc/$recipientFormat.asc

			returnText \
				"Address encrypted for " \
				"${bs}" \
				"${recipient}" \
				"${be}" \
				"\n" \
				"to " \
				"${gpgDir}" \
				"/asc/" \
				"${bs}" \
				"${recipientFormat}" \
				".asc " \
				"${be}" \
				"!" \
				"${end}"

		else
			# Encrypt message for recipient

			recipientFormat=$(
				echo -n 'msg_for_';
				echo -n $recipient |
				sed 's/@.\+$/_/';
				date +%Y%m%d_%H%M%S
			)

			$editor txt/tmp.txt
			gpg \
				--trust-model always \
				--armor \
				--encrypt \
				--recipient $recipient \
				txt/tmp.txt

			mv txt/tmp.txt.asc asc/$recipientFormat.asc
			rm txt/tmp.txt

			returnText \
				"Message encrypted for " \
				"${bs}" \
				"${recipient}" \
				"${be}" \
				"\n" \
				"to" \
				"${gpgDir}" \
				"/asc/" \
				"${bs}" \
				"${recipientFormat}" \
				".asc" \
				"${be}" \
				" !"


		fi

	fi

}

function decryptMsg() {

	cd $gpgDir
	messages=$(ls -1 asc/ | grep '^msg')

	echo "Please select a message to decrypt : "
	toDecryptMsg=$(echo -e "$messages" | $fzf)

	if [ ! -z $toDecryptMsg ]; then

		gpg \
			--output txt/$toDecryptMsg.txt \
			--decrypt asc/$toDecryptMsg

		returnText \
			"Message successfully decrypted to" \
			"\n" \
			"${gpgDir}" \
			"/txt/" \
			"${bs}" \
			"${toDecryptMsg}" \
			".txt" \
			"${be}" \
			" !" \
			"${end}" \
			"\n\n" \
			"Would you like to open the message now ?" \

		# Open message then go to menu
		answerMsg=$(echo -e '[Y] Yes\n[N] No' | $fzf)

		if [ "$answerMsg" == "[Y] Yes" ]; then
			$editor txt/$toDecryptMsg.txt
		fi
		toMenu


	fi

}

function exportPubKey() {
	cd $gpgDir
	echo -e "\nPlease select a public key to export : "
	public=$(selectKey)

	if [ ! -z $public ]; then

		pubFormat=$(echo -n $public |
			sed 's/@.\+$/_/' |
			sed 's/\./_/g'; echo 'pub.asc')

		gpg -ao pub/${pubFormat} --export ${public}

		returnText \
			"Public key successfully exported to " \
			"${gpgDir}" \
			"/pub/" \
			"${bs}" \
			"${pubFormat}" \
			"${be}" \
			" !"
	fi

}

function signFile() {
	cd $gpgDir
	echo -e "\nPlease select a file to sign : "
	file=$(ls asc/ txt/ |
		sed '/.*\/:/d' |
		sed '/^$/d' |
		head -n99 |
		$fzf)

	if [ ! -z $file ]; then

		gpg \
			--armor \
			--output sig/${file}.sig \
			--detach-sig $(find |
				grep $file |
				tail -n1)

		returnText \
			"Signature for message successfully written to" \
			"\n" \
			"${gpgDir}" \
			"/sig/" \
			"${bs}" \
			"${file}" \
			".sig" \
			"${be}" \
			" !"

	fi

}

function verifyFile() {
	cd $gpgDir
	echo -e "\nPlease select a file to verify : "
	signature=$(ls sig/ | $fzf)

	if [ ! -z $signature ]; then

		fileSign=$(find asc/ txt/ |
			grep $(echo $signature | sed 's/\.sig$//'))

		gpg --verify sig/${signature} ${fileSign}

		returnText \
			"Message successfully verified !"

	fi

}

checkDependencies
