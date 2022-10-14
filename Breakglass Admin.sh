#!/bin/bash

: HEADER = <<'EOL'

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

        Name: Break Glass Admin
 Description: Creates/manages a hidden admin account with a random password
  Created By: Chad Lawson
     Version: 4.2
     License: Copyright (c) 2022, Rocketman Management LLC. All rights reserved. Distributed under MIT License.
   More Info: For Documentation, Instructions and Latest Version, visit https://www.rocketman.tech/jamf-toolkit
  Parameters: $1-$3 - Reserved by Jamf (Mount Point, Computer Name, Username)
              $4 - The username and (optionally) full name of the admin account
              $5 - Which method of creating a password to use (see below)
              $6 - Name of extension attribute where password is stored
                   (e.g. "Breakglass Admin")
              $7 - Storage method: Provide BASE64 encoded "user:password" for
                                   storage via API. 
                                   Otherwise locally stored in System Keychain.
              $11- Overrides (optional) - See GitHub for usage

Available Password Methods:
            'nato' - Combines words from the NATO phonetic alphabet
                     (e.g. "WhiskeyTangoFoxtrot")
            'xkcd' - Using the system from the XKCD webcomic
                     (https://xkcd.com/936)
           'names' - Same as above but only with the propernames database
			'wopr' - Like the launch codes in the 80s movie, "Wargames"
					[https://www.imdb.com/title/tt0086567]
					(e.g. "CPE 1704 TKS")
    'pseudoRandom' - Based on University of Nebraska' LAPS system
                    (https://github.com/NU-ITS/LAPSforMac)
'custom' (default) - Customizable format with the following defaults
                     * 16 characters
                     * 1 Upper case character (min)
                     * 1 Lower case character (min)
                     * 1 Digit (min)
                     * 1 Special character (min)
                     Optionally you can add a string to specify overrides
                     in the following format:
                       N=20;U=3;L=1;D=2;S=0


EOL

##
## Defining Parameters and Variables
##

## User-related components
ADMINUSER=$([ "$4" ] && echo "$4" || echo "breakglass Breakglass Admin")
USERNAME=$(echo "${ADMINUSER}" | sed -nr 's/^([^\ ]+)\ (.*)$/\1/p' )
FULLNAME=$(echo "${ADMINUSER}" | sed -nr 's/^([^\ ]+)\ (.*)$/\2/p' )
FULLNAME=$( [[ $FULLNAME != "" ]] && echo "${FULLNAME}" || echo ${USERNAME} )

## Choose the password generation method
## E.g. nato, wopr, xkcd, names, pseudoRandom
PASSMODE=$([ "$5" ] && echo "$5" || echo "custom")

## Name of the extension attribute to store password
EXTATTR=$([ "$6" ] && echo "$6" || echo "Breakglass Admin Password")

## API User "Hash" - Base64 encoded "user:password" string for API use
APIHASH=$([ "$7" ] && echo "$7" || echo "")

## Other Main Defaults
## These can either be harcoded here or overriden with $11 (see below)
DEBUG='' ## Default is off.
NUM=''  ## Override for each password method's defaults
        ##           nato =  3 words
        ##           xkcd =  4 words
        ##           name =  4 names
        ##   pseudoRandom = 16 characters
HIDDENFLAG="-hiddenUser" ## Set to empty for visible
FORCE="0" ## 1 (true) or 0 (false) - USE WITH EXTREME CAUTION!
          ## If true and old password is unknown or can't be changed,
          ## the script will delete the account and re-create it instead.
STOREREMOTE="" ## Set to 'Yes' below -IF- APIHASH is provided
STORELOCAL=""  ## Set to 'Yes' below -IF- no APIHASH or overriden
KEYCHAIN="/Library/Keychains/System.keychain"

## Allow for overrides of everything so far...
## If the 11th policy parameter contains an equal sign, run eval on the
## whole thing.
## Example: If $11 is 'NUM=5;HIDDENFLAG=;FORCE=1;STORELOCAL="Yes"', then
##  the values of the variables with the same name of those above would change.
## WARNING! This would be HORRIBLE security in a script that remains local
##          as any bash-savvy user could inject whatever code they wanted to.
##          This danger is LESSENED by the fact that the parameters are
##          provided at run-time by Jamf and the script is not stored on
##          the computer outside the policy run.
[[ "${11}" == *"="* ]] && eval ${11} ## Comment out to disable

## Finalize storage options
if [ ${APIHASH} ]; then
	STOREREMOTE="Yes"
	JAMFURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
	SERIAL=$(system_profiler SPHardwareDataType | grep -i serial | grep system | awk '{print $NF}')
else
  STORELOCAL="Yes"
fi

##
## Defining Functions
##

function debugLog () {
  if [[ ${DEBUG} ]]; then
	 message=$1
	 timestamp=$(date +'%H%M%S')

	 echo "${timestamp}: ${message}" >> /tmp/debug.log
  fi
}

function createRandomPassword() {
	system=$1

	case "$system" in

		nato) ## Using NATO Letters (e.g. WhiskeyTangoFoxtrot)
			NUM=$([ ${NUM} ] && echo ${NUM} || echo "3")
			NATO=(Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey Yankee Zulu)
			MAX=${#NATO[@]}
			NEWPASS=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do  echo -n ${NATO[$u]} ; done)
			;;

		xkcd) ## Using the system from the XKCD webcomic (https://xkcd.com/936/)
			NUM=$([ ${NUM} ] && echo ${NUM} || echo "4")
			## Get words that are betwen 4 and 6 characters in length, ignoring proper nouns
			MAX=$(awk '(length > 3 && length < 9 && /^[a-z]/)' /usr/share/dict/words | wc -l)
			CHOICES=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do awk '(length > 3 && length < 7 && /^[a-z]/)' /usr/share/dict/words 2>/dev/null | tail +${u} 2>/dev/null | head -1 ; done)
			NEWPASS=""
			for word in ${CHOICES}; do
				first=$(echo $word | cut -c1 | tr '[[:lower:]]' '[[:upper:]]')
				rest=$(echo $word | cut -c2-)
				NEWPASS=${NEWPASS}${first}${rest}
			done
			;;

		names) ## Uses the same scheme as above but only with the propernames database
			NUM=$([ ${NUM} ] && echo ${NUM} || echo "4")
			MAX=$(wc -l /usr/share/dict/propernames | awk '{print $1}')
			CHOICES=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do tail +${u} /usr/share/dict/propernames 2>/dev/null | head -1 ; done)
			NEWPASS=$(echo "${CHOICES}" | tr -d "[:space:]" )
			;;

		wopr) ## Like the launch codes in the 80s movie "Wargames" (https://www.imdb.com/title/tt0086567)
			## (Example "CPE 1704 TKS")
			## Fun Fact - The odds of getting the same code as in the movie is roughly three trillion to one.
			PRE=$(jot -nrc -s '' 3 65 90)
			NUM=$(jot -nr -s '' 4 0 9)
			POST=$(jot -nrc -s '' 3 65 90)
			NEWPASS="${PRE} ${NUM} ${POST}"
			;;
		
		pseudoRandom) ## Based on University of Nebraska' LAPS system (https://github.com/NU-ITS/LAPSforMac)
			NUM=$([ ${NUM} ] && echo ${NUM} || echo "16")
			## Remove Ambigious characters
			NEWPASS=$(openssl rand -base64 100 | tr -d OoIi1lLS | head -c${NUM};echo)
			;;

		custom* | *) ## Adjustable scheme
			## Example: "custom N=16;S=1;D=2;L=3;U=4"

			## Defaults
			N=16 # Password length
			S=1  # Minimum special characters
			U=1  # Minimum upper case
			L=1  # Minimum lower case
			D=1  # Minumum digits

			## NOTE:
			## If N < S+U+L+D, then N = S+U+L+D
			## If N > S+U+L+D, then random characters from the ENTIRE range will be used to fill

			## If there are overrides passed in, use them
			INPUT=$(echo ${system} | awk '{print $2}')
			eval ${INPUT}

			## 33-126 - All the printable characters
			## 48-57 - Digits
			## 65-90 - Upper
			## 97-122 - Lower

			## Generate the minimums
			UC=($([ ${U} -gt 0 ] && echo $(jot -r ${U} 65 90)  || echo ""))  ## Upper case
			LC=($([ ${L} -gt 0 ] && echo $(jot -r ${L} 97 122) || echo "")) ## Lower Case
			NC=($([ ${D} -gt 0 ] && echo $(jot -r ${D} 48 57)  || echo ""))  ## Digits
			## Special characters
			SN=()
			if [ ${S} -gt 0 ]; then
				SCNA=({33..47} {58..64} {91..96} {122..126})
				for x in $(jot -r ${S} 0 ${#SCNA[@]}); do
					SN+=(${SCNA[$x]})
				done
			fi

			## Put the minimums together
			ALL=(${UC[@]} ${LC[@]} ${NC[@]} ${SN[@]})

			## How many more characters do we need
			LO=$(($N-$S-$U-$L-$D))
			## Pull any remaining characters from the whole set
			if [[ $LO -gt 0 ]]; then
				for x in $(jot -r $LO 33 126); do
					ALL+=(${x})
				done
			fi

			## Build the password by shuffling the bits
			passArray=()
			while [ ${#ALL[@]} -gt 0 ]; do
				i=$(jot -r 1 0 $(( ${#ALL[@]}-1 )))
				passArray+=(${ALL[$i]})
				ALL=( ${ALL[@]/${ALL[$i]}} )
			done
			NEWPASS="$(printf '%x' ${passArray[@]} | xxd -r -p)"
			;;

	esac

	echo ${NEWPASS}
}

function createBreakglassAdmin() {
	## Using the built-in jamf tool which beats the old way which doesn't work
	## across all OS versions the same way.
	echo "Creating ${ADMINUSER}"
		jamf createAccount \
		-username ${USERNAME} \
		-realname "${FULLNAME}" \
		-password "${NEWPASS}" \
		–home /private/var/${USERNAME} \
		–shell “/bin/zsh” \
		${HIDDENFLAG} \
		-admin \
		-suppressSetupAssistant
}

function changePassword() {
	## Delete keychain if present
	rm -f "~${USERNAME}/Library/Keychains/login.keychain"

	## Change password
	echo "jamf changePassword -username ${USERNAME} -oldPassword \"${OLDPASS}\" -password \"${NEWPASS}\"" 
	jamf changePassword -username ${USERNAME} -oldPassword "${OLDPASS}" -password "${NEWPASS}"

	## If we are forcing the issue
	if [[ $? -ne 0 ]]; then ## Error
		echo "ERROR: $?" >> /tmp/debug.log
		if [[ ${FORCE} ]]; then
			echo "Delete and recreate"
			jamf deleteAccount -username ${USERNAME} -deleteHomeDirectory
			createBreakglassAdmin
		else
			## Log it
			NEWPASS="EXCEPTION - Password change failed: $?"
		fi
	fi
}

function getCurrentPassword() {

	if [[ $STOREREMOTE ]]; then
		## Get the password through the API
		CURRENTPASS=$( \
			curl -s \
			-H "Authorization: Bearer ${TOKEN}" \
			-H "Accept: text/xml" \
			${JAMFURL}/JSSResource/computers/serialnumber/${SERIAL}/subset/extension_attributes \
			| xmllint --xpath "//*[name='${EXTATTR}']/value/text()" - \
		)
	elif [[ ${STORELOCAL} ]]; then
		CURRENTPASS=$(security find-generic-password -w -a "${USERNAME}" -s "${EXTATTR}" "${KEYCHAIN}" 2>/dev/null)
	else
      CURRENTPASS="EXCEPTION - No storage method selected" ## This -should- never happen
	fi

	## Pass it back
	echo $CURRENTPASS
}

function storeCurrentPassword() {
	
	## Store the password locally for pickup by Recon
	if [[ ${STORELOCAL} ]]; then
		## Since updating requires the user to intervene, we'll first delete the old one
		security delete-generic-password -a "${USERNAME}" -s "${EXTATTR}" "${KEYCHAIN}" &>/dev/null
		## Now we'll add it (back)
		security add-generic-password -a "${USERNAME}" -s "${EXTATTR}" -w "${NEWPASS}" -A "${KEYCHAIN}" 2>/dev/null
		## TODO: Add bit to verify storage
	fi

	## Store the password in Jamf
	if [[ ${STOREREMOTE} ]]; then
		XML="<computer><extension_attributes><extension_attribute><name>${EXTATTR}</name><value>${NEWPASS}</value></extension_attribute></extension_attributes></computer>"
		debugLog "XML: ${XML}"
		curl -s \
			-H "Authorization: Bearer ${TOKEN}" \
			-H "Content-type: application/xml" \
			"${JAMFURL}/JSSResource/computers/serialnumber/${SERIAL}" \
			-X PUT \
			-d "${XML}"
	fi
	## TODO: Add return code handling
}

function getAPIToken() {
	authToken=$(curl -s \
		--request POST \
		--url "${JAMFURL}/api/v1/auth/token" \
		--header "Accept: application/json" \
		--header "Authorization: Basic ${APIHASH}" \
		2>/dev/null \
	)
	
	## Courtesy of Der Flounder
	## Source: https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/
	if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
		api_token=$(/usr/bin/awk -F \" 'NR==2{print $4}' <<< "$authToken" | /usr/bin/xargs)
	else
		api_token=$(/usr/bin/plutil -extract token raw -o - - <<< "$authToken")
	fi

	echo ${api_token}
}

##
## Main Script
##

## If we are using remote, get a Jamf Pro API token
if [ ${APIHASH} ]; then
	TOKEN=$(getAPIToken)
fi

## See if the user exists
EXISTS=$(id ${USERNAME} 2>/dev/null | wc -l | awk '{print $NF}')

## Either way, we'll need a random password
NEWPASS=$(createRandomPassword ${PASSMODE})
debugLog "NewPass: ${NEWPASS}"

## Are we creating the user or changing their password
if [[ $EXISTS -gt 0 ]]; then
	debugLog "Exists: Changing"

	## Get the existing password
	OLDPASS=$(getCurrentPassword)
	debugLog "Old: ${OLDPASS}"

	## Exception Block
	## This was added to handle the computers that had an account prior to enrollment.
	## To change a password, we need to know the old one. If there is an issue storing
	## or retreiving the password, the issue will be stored for reporting and mitigation.
	##
	## ADDITIONAL NOTE: If the record for any previous computer is updated with the correct password
	##		this script will run normally next time and update with a random password
	case ${OLDPASS} in
    ## No password found
		"")
			debugLog "Old password unknown - create exception"
			## The account was created before and is unknown
			NEWPASS="EXCEPTION - Unknown password"
			;;

    ## If a previous run had an issue, the 'password' was logged as an 'EXCEPTION'.
		EXCEPTION*) 
			debugLog "Previous exception - ${OLDPASS}"
			if [[ ${FORCE} ]]; then
				## Request a password change with known bad data to trigger refresh
				OLDPASS="NULL"
				changePassword
			else ## Previous error not resolved. Re-asserting.
				NEWPASS=${OLDPASS}
			fi
			;;

    ## All is well. Moving on.
		*)
			debugLog "Changing from ${OLDPASS} to ${NEWPASS}"
			## Change the password
			changePassword
			;;
	esac
	## End exception block

else ## User does not exist. We are creating it.

	## Create the account
	debugLog "Creating new admin."
	## Create the user
	createBreakglassAdmin

fi

## Store the new password
storeCurrentPassword

## Dump and clear the debug log
if [[ -f /tmp/debug.log ]]; then
	echo $(cat /tmp/debug.log)
	rm /tmp/debug.log
fi

exit 0
