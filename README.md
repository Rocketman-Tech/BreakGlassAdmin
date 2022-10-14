# BreakGlass Admin
<img src="images/breakglass.jpg" height="200" align=right alt="In case of emergency, break glass">

A workflow to create/manage a rotating backdoor admin account.

## Background

Where there are several other implementations of LAPS for Macs out in the Jamf Nation and Mac Admins communities, this version was created to serve as a single solution for all our clients that can be configured through policy parameters.

## How it Works:

This workflow will create a backdoor admin account on each mac it’s run on, randomize the password, and store the password in an Extension Attribute in Jamf Pro. It works great out of the box without any configuration, but can also be easily configured to fit your organization’s standards.

## Parameters
These are the parameters set in Jamf and how to configure them:

- Parameter 4: The username and (optionally) full name of the admin account
	- Label: Admin Username and Full Name
	- Type: String
	- Example: breakglass Breakglass Admin

- Parameter 5: Which method of creating a password to use (see Available Password Methods below)
	- Label: Available Password Methods
	- Type: Single Choice
	- Choices: nato | wopr | xkcd | names | pseudoRandom | custom
	- Instructions: See Available Password Methods below
	- Example: nato

- Parameter 6: Name of extension attribute where password is store
	- Label: Extension Attribute
	- Type: String
	- Example: Breakglass Admin Password

- Parameter 7: Password Storage Method: Provide BASE64 encoded "user:password" for storage via API. Otherwise locally stored. (See Password Storage Method below)
	- Label: API Hash
	- Type: Base64 Encoded String
	- Permissions: API User with the following permissions
	- Computers: Read | Update
	- Computer Extension Attributes: Read | Update
	- Users: Read | Update
	- Instructions: See Password Storage Method Below
	- Example: R3JlZXRpbmdzLCBQcm9mZXNzb3IgRmFsa2VuLgo=
	
- Parameter 11: Overrides (optional)
	- Label: Overrides
	- Type: String
	- Instructions: See Below
	- Example: NUM=5;HIDDENFLAG=;FORCE=1;STORELOCAL="Yes"

## Available Password Methods
The randomized password that is set can be set a number of different ways, some more readable than others. Here are the options:

- nato - Combines three (by default) NATO phonetic letters (e.g. WhiskeyTangoFoxtrot)
- wopr - Like the launch codes in the 80s movie, "Wargames" (e.g. "CPE 1704 TKS")
- xkcd - Uses the system from the XKCD webcomic (https://xkcd.com/936/) by pulling four (by default) words between 4-8 characters long from /usr/share/dict/words (e.g. CorrectHorseBatteryStaple)
- names - Uses the same scheme as above but only with the propernames database (e.g. AliceBobEveMallory)
- pseudoRandom - Based on University of Nebraska' LAPS system (https://github.com/NU-ITS/LAPSforMac)
- custom - Customizable format with the following defaults:
	- 16 characters
	- 1 Upper case character (min)
	- 1 Lower case character (min)
	- 1 Digit (min)
	- 1 Special character (min)
	- Optionally you can add a string to specify overrides in the following format: N=20;U=3;L=1;D=2;S=0

## Password Storage Options

**Storing the password using the Jamf API**

Provide the base64 encoded username and password of a Jamf Pro (API) user account with the following permissions:

- Computers: Read | Update
- Computer Extension Attributes: Read | Update
- Users: Read | Update

To get the encoded string, enter the following command into Terminal:

echo -n "USERNAME:PASSWORD" | base64 | pbcopy

Where USERNAME and PASSWORD should be replaced the appropriate info.

**Note:** This will NOT display any result. Instead it will be in your clipboard for pasting elsewhere. Because 'echo -n' prevents a final line-feed, it can be confusing which parts you need to copy.

**Storing the password on the local client**
The only issue with storing the password through the API is that sometimes the API command fails because of an internet blip, and the password is lost (although it is saved temporarily in the logs), which is a more consistent way of storing the password would be to a local file.

To give companies the option, if this parameter is blank, the password will be stored locally in the system keychain.

## Overrides
The “Overrides” parameter allows you to set multiple variables through one parameter. This is useful when doing advanced customization of this workflow without having to change the actual code. Below are the variables that can be set through this:

- DEBUG=’’
	- Default is off. Any value makes it true.
- NUM='' 
	- Override for each password method's defaults
	- nato =  3 words
	- xkcd =  4 words
	- name =  4 names
- HIDDENFLAG="-hiddenUser"
	- Set to empty for visible
- FORCE="0" 
	- 1 (true) or 0 (false) - USE WITH EXTREME CAUTION!
	- If true and old password is unknown or can't be changed, the script will delete the account and re-create it instead.
- STOREREMOTE=""
	- Set to 'Yes' below -IF- APIHASH is provided
- STORELOCAL=""
	- Set to 'Yes' below -IF- no APIHASH or overriden
- KEYCHAIN="/Library/Keychains/System.keychain"

For example; if 'nato' was the selected password method and the following was entered into parameter 11 of the policy:

NUM=5;HIDDENFLAG=;FORCE=1;STORELOCAL="Yes"

The resulting changes would take place:
- The password would consist of five NATO words instead of three
- The admin account would be created as visible in System Preferences and with a UID > 500
- If the existing password can't be found or if the password change fails, the FORCE option will attempt to delete the account and re-create it
- The password will be stored in the local file even if the remote option is used
**Note:** As mentioned in the comment block, running 'eval' on an unsanitized string would be a terrible idea with a normal script. For a Jamf script, some may still consider it problematic. In which case, simply comment out or delete the line.

## Supplemental Scripts
There are two additional support scripts in this repository:
- Extension Attribute.sh - If you are choosing to store the password on the client side, but want it copied into Jamf, create a script-based extension attribute with this code to have each computer send that password during recon.

## Deployment
Because of the complexity of this script when setting up for the first time, we recommend using Rocketman’s Auto Deploy workflow to deploy the Break Glass account for the first time. This will set everything up, out-of-the box, without any customization, and allows for additional customization from there. 
