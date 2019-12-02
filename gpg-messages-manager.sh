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
fzf="fzf --height 65% --layout=reverse --border"

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
 		mkdir -p Documents/pgp/{asc,pub,txt}

 	elif [ ! -d Documents/pgp ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt}

 	elif [ ! -d Documents/pgp/asc ]; then
 			mkdir Documents/pgp/asc

 	elif [ ! -d Documents/pgp/pub ]; then
 			mkdir Documents/pgp/pub

 	elif [ ! -d Documents/pgp/txt ]; then
 			mkdir Documents/pgp/txt

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

function showMenu() {
	clear
	echo "${bs}Welcome to GnuPG !${be}"
	askOption
}

function askOption() {

	choice=$(echo -e "[0] Show keyring
[1] Generate a new key pair
[2] Import a public key
[3] Export a public key
[4] Remove a public key
[5] Encrypt your address
[6] Encrypt a message
[7] Decrypt a message
[8] Sign a file
[9] Verify a file
[!] Exit" |
	$fzf |
	cut -d ' ' -f1 |
	grep -oE '[0-9]+'
	)

	if [ ! -z $choice ]; then
		if [ $choice -eq $choice 2>/dev/null ]; then
			while [[ $choice -lt 0 || $choice -gt 9 ]]; do
				echo -e "\nPlease choose between 0 - 9 !"
				read -p ">>> " choice
			done
		fi
	else
		exit 0
	fi

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
	esac
}

function showKeys() {
	if [ "$1" == "i" ]; then
		echo
	fi

	gpg --list-keys |
		grep -E '^uid' |
		sed 's/^.\+\] //' |
		sed 's/>//' |
		sed 's/ </;/' |
		cut -d ';' -f 1- --output-delimiter=$'\t\t\t'

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
		gpg --gen-key
	fi

	toMenu
}

function addPubKey() {
	cd $gpgDir
	echo "Please select a public key : "
	public=$(ls pub/ | head | $fzf)
	gpg --batch --yes --import pub/$public

	if [ $? -eq 0 ]; then
		echo -e "${green}\nPublic key $public added !${end}"
	else
		echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
	fi

	toMenu
}

function delPubKey() {
	echo "Please select a public key : "
	public=$(selectKey)
	gpg --batch --yes --delete-key $public

	if [ $? -eq 0 ]; then
		echo -e "${green}Public key $public deleted !${end}"
	else
		echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
	fi

	toMenu
}

function encryptMsg() {
	cd $gpgDir
	echo "Please select a recipient : "
	recipient=$(selectKey)

	if [ "$1" == "adr" ]; then
		gpg --trust-model always --armor --encrypt --recipient $recipient txt/adr.txt

		if [ $? -eq 0 ]; then
			recipientFormat=$(echo -n 'adr_for_'; echo $recipient | sed 's/@.\+$//')
			mv txt/adr.txt.asc asc/$recipientFormat.asc

			echo -e "\n${green}Address encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
		fi

	else
		$editor txt/tmp.txt
		gpg --trust-model always --armor --encrypt --recipient $recipient txt/tmp.txt

		if [ $? -eq 0 ]; then
			recipientFormat=$(echo -n 'msg_for_'; echo -n $recipient | sed 's/@.\+$/_/'; date +%Y%m%d_%H%M%S)
			mv txt/tmp.txt.asc asc/$recipientFormat.asc
			rm txt/tmp.txt

			echo -e "\n${green}Message encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
		fi
	fi

	echo 'RELOADAGENT' | gpg-connect-agent
	toMenu
}

function decryptMsg() {
	cd $gpgDir
	messages=$(ls asc/ | grep '^msg' | head -n99)
	echo "Please select a message : "
	toDecryptMsg=$(echo -e "$messages" | $fzf)
	gpg --output txt/$toDecryptMsg.txt --decrypt asc/$toDecryptMsg

	if [ $? -eq 0 ]; then
		echo -e "\n${green}Message successfully decrypted to $gpgDir/txt/${bs}$toDecryptMsg.txt${be} !${end}"
		echo -e "\nWould you like to see the message now ?\n[Y]es / [N]o\n"
		read -p ">>> " answerMsg

		while [[ ! $answerMsg == "Y" && ! $answerMsg == "y" && ! $answerMsg == "N" && ! $answerMsg == "n" ]]; do
			echo -e "\nPlease choose between Y or N !"
			read -p ">>> " answerMsg
		done

		if [[ $answerMsg == "Y" || $answerMsg == "y" ]]; then
			$editor txt/$toDecryptMsg.txt
		fi
	else
		echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
	fi

	echo 'RELOADAGENT' | gpg-connect-agent
	toMenu
}

function exportPubKey() {
	cd $gpgDir
	echo -e "\nPlease select a public key : "
	public=$(selectKey)
	pubFormat=$(echo -n $public | sed 's/@.\+$/_/' | sed 's/\./_/g'; echo 'pub.asc')
	gpg -ao pub/${pubFormat} --export ${public}

	if [ $? -eq 0 ]; then
		echo -e "\n${green}Public key successfully exported to $gpgDir/pub/${bs}${pubFormat}${be} !${end}"
	else
		echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

function signFile() {
	cd $gpgDir
	echo -e "\nPlease select a file : "
	file=$(ls asc/ txt/ | sed '/.*\/:/d' | sed '/^$/d' | head -n99 | $fzf)
	gpg --armor --output sig/${file}.sig --detach-sig $(find | grep $file | tail -n1)

	if [ $? -eq 0 ]; then
		echo -e "\n${green}File successfully signed to $gpgDir/sig/${bs}${file}.sig${be} !${end}"
	else
		echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

function verifyFile() {
	cd $gpgDir
	echo -e "\nPlease select a file : "
	signature=$(ls sig/ | $fzf)
	fileSign=$(find asc/ txt/ | grep $(echo $signature | sed 's/\.sig$//'))
	gpg --verify sig/${signature} ${fileSign}

	if [ $? -ne 0 ]; then
		exit 1
	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

checkDependencies
