#!/bin/bash

# To configure settings for this script, run the script directly at the command line

# File to watch for backup, source and local backup paths
FILETOBACKUP="channel.backup"
SOURCEFOLDER="/home/bitcoin/.lnd/data/chain/bitcoin/mainnet/"
SOURCEFILE="${SOURCEFOLDER}${FILETOBACKUP}"
LOCALBACKUPFOLDER="/home/bitcoin/backups/lnd/"
LOCALBACKUPFILE="${LOCALBACKUPFOLDER}${FILETOBACKUP}"
value_not_set="not-set"
DROPBOX_APPNAME="LND Channel Backup Archive"
DROPBOX_APPKEY=$value_not_set
DROPBOX_APPSECRET=$value_not_set
DROPBOX_ACCESS_CODE=$value_not_set
DROPBOX_ACCESS_TOKEN=$value_not_set
DROPBOX_REFRESH_TOKEN=$value_not_set
DEVICE=$(hostname)
color_red='\033[0;31m'
color_green='\033[0;32m'
color_yellow='\033[0;33m'
color_blue='\033[0;34m'
color_purple='\033[0;35m'
color_cyan='\033[0;36m'
color_white='\033[0;37m'
color_normal=${color_white}
color_currentvalue=${color_purple}
color_newvalue=${color_yellow}
color_link=${color_green}
configlevel=0

refresh_token() {
  printf "\nRefreshing token"
  RESPONSE=$(curl https://api.dropboxapi.com/oauth2/token \
      -d grant_type=refresh_token \
      -d refresh_token=${DROPBOX_REFRESH_TOKEN} \
      -u ${DROPBOX_APPKEY}:${DROPBOX_SECRET} \
      )
  ISERR=$(echo RESPONSE | grep error | wc -l)
  if [ $ISERR -gt 0 ]; then
    printf "\nError refreshing token. May need to reconfigure using access code or re-approving application"
    printf "\nResponse: ${RESPONSE}"
    exit 1
  else
    DROPBOX_ACCESS_TOKEN=$(echo $RESPONSE | jq -r .access_token)
    printf "\nNew token is ${DROPBOX_ACCESS_TOKEN}"
    config_save
  fi
}

check_user() {
  RESPONSE=$(curl -s -X POST https://api.dropboxapi.com/2/check/user \
      --header "Authorization: Bearer "${DROPBOX_ACCESS_TOKEN}"" \
      --header "Content-Type: application/json" \
      --data "{\"query\": \"678362\"}" \
      )
  ISERR=$(echo RESPONSE | grep error | wc -l)
  if [ $ISERR -gt 0 ]; then
    refresh_token
  else
    RESULT=$(echo $RESPONSE | jq -r .result)
    if [ $RESULT != "678362" ]; then
      refresh_token
    fi
  fi
}

upload_to_dropbox() {
  check_user
  FINISH=$(curl -s -X POST https://content.dropboxapi.com/2/files/upload \
      --header "Authorization: Bearer "${DROPBOX_ACCESS_TOKEN}"" \
      --header "Dropbox-API-Arg: {\"path\": \"/"${DEVICE}${1}"\",\"mode\": \"add\",\"autorename\": true,\"mute\": false,\"strict_conflict\": false}" \
      --header "Content-Type: application/octet-stream" \
      --data-binary @$1)
  UPLOADTIME=$(echo $FINISH | jq -r .server_modified)
  if [ ! -z $UPLOADTIME ] ; then
    printf "\nSuccessfully uploaded $1!"
  else
    printf "\nUnknown error when uploading $1..."
  fi
}

setup_backup_filename() {
  bfe=true
  bfc=0
  while $bfe
  do
    # get a time stamp in seconds since epoch
    NEWFILEDATE=`date +%s`
    # determine backup file name
    BACKUPFILE="${LOCALBACKUPFILE}.${NEWFILEDATE}"
    if [ ! -f "${BACKUPFILE}" ]; then
      bfe=false
    else
      bfc=$((bfc++))
      if [ $bfc -ge 5 ]; then
        bfe=false
        break
      fi
      sleep 0.1
    fi
  done
}

service_loop() {
  config_load "validate"
  three_hours=10800
  while true; do
    # wait for change to source file
    inotifywait --timeout $three_hours $SOURCEFILE
    ec=$(echo $?)
    if [ $ec -eq 0 ]; then
      # file changed
      setup_backup_filename
      MD5SUMFILE="${BACKUPFILE}.md5"
      # copy source to backup and get md5 sum file
      cp $SOURCEFILE $BACKUPFILE
      md5sum $BACKUPFILE > $MD5SUMFILE
      sed -i 's/\/.*\///g' $MD5SUMFILE
      # upload backup file
      upload_to_dropbox $BACKUPFILE
      upload_to_dropbox $MD5SUMFILE
    fi
    if [ $ec -eq 2 ]; then
      # inotifywait timed out
      refresh_token
    fi
  done
}

guidance_create_dropbox_app() {
  printf "\nYou will need to create a Dropbox App to use this script."
  printf "\nYou can create a new Dropbox App at https://dropbox.com/developers/apps"
  printf "\n  1. Choose an API - select scoped access"
  printf "\n  2. Choose the type of access you need - select App folder"
  printf "\n  3. Name your app - Any name you want that is allowed per Dropbox constraints."
  printf "\n     The name you specify will be used to create a folder in your Dropbox "
  printf "\n     account at /Apps/NAME_OF_APP"
  printf "\n  4. On the permissions tab for the application check the box for"
  printf "\n     'files.content.write' and then click submit to apply permission changes."
  read -p "$(printf "\nOnce this is complete, press enter to continue.")"
  configlevel=1
}

prompt_dropbox_app_key() {
  printf "\n\n${color_normal}Dropbox App Key"
  while true
  do
    printf "\nThis is available on the settings tab of your Dropbox application."
    printf "\nCurrent value: ${color_currentvalue}${DROPBOX_APPKEY}${color_normal}"
    read -p "$(printf "\nProvide a new value, or simply press return to keep the current value ${color_newvalue}")" answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      DROPBOX_APPKEY=${answer}
    fi
    if [ $DROPBOX_APPKEY != $value_not_set ]; then
      configlevel=2
      break
    else
      printf "\nYou must set a value to continue configuration"
    fi
  done
}

prompt_dropbox_app_secret() {
  printf "\n\n${color_normal}Dropbox App Secret"
  while true
  do
    printf "\nThis is available on the settings tab of your Dropbox application."
    printf "\nYou may need to click the 'Show' button to reveal the Dropbox App Secret"
    printf "\nCurrent value: ${color_currentvalue}${DROPBOX_APPSECRET}${color_normal}"
    read -p "$(printf "\nProvide a new value, or simply press return to keep the current value ${color_newvalue}")" answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      DROPBOX_APPSECRET=${answer}
    fi
    if [ $DROPBOX_APPSECRET != $value_not_set ]; then
      configlevel=3
      break
    else
      printf "\nYou must set a value to continue configuration"
    fi
  done
}

prompt_dropbox_access_code() {
  printf "\n\n${color_normal}Dropbox Access Code"
  while true
  do
    printf "\nTo get an access code, you must authorize the application access to your account"
    printf "\nUse a web browser to navigate to this link to connect the app to your account"
    printf "\n${color_link}  https://www.dropbox.com/oauth2/authorize?client_id=${DROPBOX_APPKEY}&token_access_type=offline&response_type=code "
    printf "\n${color_normal}Once you have allowed the application, you will be presented with an access code."
    printf "\nCurrent value: ${color_currentvalue}${DROPBOX_ACCESS_CODE}${color_normal}"
    read -p "$(printf "\nProvide a new value, or simply press return to keep the current value ${color_newvalue}")" answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      DROPBOX_ACCESS_CODE=${answer}
    fi
    if [ $DROPBOX_ACCESS_CODE != $value_not_set ]; then
      configlevel=4
      break
    else
      printf "\nYou must set a value to continue configuration"
    fi
  done
}

get_auth_tokens() {
  printf "\nAccess code being used to retrieve access token and refresh token"
  RESPONSE=$(curl -s https://api.dropbox.com/oauth2/token \
      -d grant_type=authorization_code \
      -d code="${DROPBOX_ACCESS_CODE}" \
      -d client_id="${DROPBOX_APPKEY}" \
      -d client_secret="${DROPBOX_APPSECRET}" \
      )
  ISERR=$(echo $RESPONSE | grep error | wc -l)
  if [ $ISERR -gt 0 ]; then
    printf "\nError retrieving access token and refresh token: ${RESPONSE}"
    DROPBOX_ACCESS_TOKEN=$value_not_set
    DROPBOX_REFRESH_TOKEN=$value_not_set
    configlevel=3
  else
    DROPBOX_ACCESS_TOKEN=$(echo $RESPONSE | jq -r .access_token)
    DROPBOX_REFRESH_TOKEN=$(echo $RESPONSE | jq -r .refresh_token)
    configlevel=5
  fi
}

prompt_dropbox_tokens() {
  printf "\n\n${color_normal}Dropbox Access Token and Refresh Token"
  printf "\nThe previously entered information will now be used to retrieve a refresh token"
  printf "\nand a short lived access token. The access token will expire every 4 hours. The"
  printf "\nrefresh token is longer lived and will be periodically used to request a new"
  printf "\naccess token.  The link that will be used to request this information is as follows"
  printf "\n${color_link}  https://api.dropbox.com/oauth2/token -d code=${DROPBOX_ACCESS_CODE} -d grant_type=authorization_code -d client_id=${DROPBOX_APPKEY} -d client_secret=${DROPBOX_APPSECRET}"
  printf "\n${color_normal}You do not have to click this link. Simply continue this script."
  while true
  do
    printf "\nThe DROPBOX_ACCESS_TOKEN is ${color_currentvalue}${DROPBOX_ACCESS_TOKEN}${color_normal}"
    printf "\nThe DROPBOX_REFRESH_TOKEN is ${color_currentvalue}${DROPBOX_REFRESH_TOKEN}${color_normal}"
    read -p "$(printf "\nPerform this step now? [Yes or No] ${color_newvalue}")" answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      answer=$(echo ${answer:0:1} | tr '[:upper:]' '[:lower:]')
      if [[ $answer == "y" ]]; then
        get_auth_tokens
        break
      fi
      if [[ $answer == "n" ]]; then
        if [ $DROPBOX_ACCESS_TOKEN != $value_not_set ]; then
          printf "\nCurrent settings for access token and refresh token will be kept"
          configlevel=5
          break
        else
          printf "\nThe access token must be set to proceed with configuration"
        fi
      fi
    fi
  done
  printf "\nThe DROPBOX_ACCESS_TOKEN is ${color_currentvalue}${DROPBOX_ACCESS_TOKEN}${color_normal}"
  printf "\nThe DROPBOX_REFRESH_TOKEN is ${color_currentvalue}${DROPBOX_REFRESH_TOKEN}${color_normal}"
}

prompt_device_name() {
  printf "\n\n${color_normal}Device Name"
  while true
  do
    printf "\nYou can use the same Dropbox application for backing up from multiple nodes."
    printf "\nA subfolder for the node identifier will be created under the app folder."
    printf "\nCurrent value: ${color_currentvalue}${DEVICE}${color_normal}"
    read -p "$(printf "\nProvide a new value, or simply press return to keep the current value ${color_newvalue}")" answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      DEVICE=${answer}
    fi
    configlevel=6
    break
  done
}

config_summary() {
  printf "${color_normal}"
  printf "\n\nConfiguration Summary"
  printf "\nDropbox App Key: ${color_current_value}${DROPBOX_APPKEY}${color_normal}"
  printf "\nDropbox App Secret: ${color_current_value}${DROPBOX_APPSECRET}${color_normal}"
  printf "\nDropbox Access Code: ${color_current_value}${DROPBOX_ACCESS_CODE}${color_normal}"
  printf "\nDropbox Access Token: ${color_current_value}${DROPBOX_ACCESS_TOKEN}${color_normal}"
  printf "\nDropbox Refresh Token: ${color_current_value}${DROPBOX_REFRESH_TOKEN}${color_normal}"
  printf "\nDevice Identity: ${color_current_value}${DEVICE}${color_normal}"
  printf "\nFile name to watch: ${color_current_value}${FILETOBACKUP}${color_normal}"
  printf "\nSource Folder: ${color_current_value}${SOURCEFOLDER}${color_normal}"
  printf "\nLocal Backup Folder: ${color_current_value}${LOCALBACKUPFOLDER}${color_normal}"
  configlevel=7
}

get_config_filename() {
  configfilename=`basename $0`
  configfilename="${configfilename}.json"
}

config_save() {
  printf "${color_normal}"
  get_config_filename
  printf "\n\nSaving updated configuration to ${configfilename}\n"
cat >${configfilename} <<EOF
{
  "dropbox": {
    "appkey": "${DROPBOX_APPKEY}",
    "appsecret": "${DROPBOX_APPSECRET}",
    "access_code": "${DROPBOX_ACCESS_CODE}",
    "access_token": "${DROPBOX_ACCESS_TOKEN}",
    "refresh_token": "${DROPBOX_REFRESH_TOKEN}"
  },
  "device": "${DEVICE}",
  "file": "${FILETOBACKUP}",
  "source_folder": "${SOURCEFOLDER}",
  "backup_folder": "${LOCALBACKUPFOLDER}"
}
EOF
}

prompt_save() {
  printf "${color_normal}"
  printf "\n\n"
  while true
  do
    read -p "Save Configuration? [Yes or No] " answer
    printf "${color_normal}"
    if [ -n "$answer" ]; then
      answer=$(echo ${answer:0:1} | tr '[:upper:]' '[:lower:]')
      if [[ $answer == "y" ]]; then
        config_save
        break
      fi
      if [[ $answer == "n" ]]; then
        break
      fi
    fi
  done
  configlevel=8
}

config_done() {
  printf "${color_normal}"
  printf "\n\nExiting\n"
  exit 0
}

config_require() {
  if [ -z "$2" ]; then
    printf "\nThe value for $1 is empty. Please run configuration.\n"
    exit 1
  fi
  if [ $2 == $value_not_set ]; then
    printf "\nThe value for $1 is ${value_not_set}. Please run configuration.\n"
    exit 1
  fi
}

config_load() {
  printf "${color_normal}"
  get_config_filename
  printf "\nLoading configuration from ${configfilename}"
  # check that file exists
  if [ ! -f "${configfilename}" ]; then
    # if running service, then fail when no configuration
    if [ "$1" == "validate" ]; then
      printf "\nConfiguration file not found. Unable to run service loop.\n"
      exit 1
    fi
  else
    # read in values
    DROPBOX_APPKEY=$(cat ${configfilename} | jq -r .dropbox.appkey)
    DROPBOX_APPSECRET=$(cat ${configfilename} | jq -r .dropbox.appsecret)
    DROPBOX_ACCESS_CODE=$(cat ${configfilename} | jq -r .dropbox.access_code)
    DROPBOX_ACCESS_TOKEN=$(cat ${configfilename} | jq -r .dropbox.access_token)
    DROPBOX_REFRESH_TOKEN=$(cat ${configfilename} | jq -r .dropbox.refresh_token)
    DEVICE=$(cat ${configfilename} | jq -r .device)
    #FILETOBACKUP=$(cat ${configfilename} | jq -r .file)
    #SOURCEFOLDER=$(cat ${configfilename} | jq -r .source_folder)
    #LOCALBACKUPFOLDER=$(cat ${configfilename} | jq -r .backup_folder)
    # validation
    if [ "$1" == "validate" ]; then
      config_require "DROPBOX_APPKEY" $DROPBOX_APPKEY
      config_require "DROPBOX_APPSECRET" $DROPBOX_APPSECRET
      config_require "DROPBOX_ACCESS_CODE" $DROPBOX_ACCESS_CODE
      config_require "DROPBOX_ACCESS_TOKEN" $DROPBOX_ACCESS_TOKEN
      config_require "DROPBOX_REFRESH_TOKEN" $DROPBOX_REFRESH_TOKEN
    fi
  fi
}

configure() {
  printf "\n${color_normal}Configuring ${DROPBOX_APPNAME}\n"
  config_load "ok"
  while true
  do
    case $configlevel in
      0)
        guidance_create_dropbox_app ;;
      1)
        prompt_dropbox_app_key ;;
      2)
        prompt_dropbox_app_secret ;;
      3)
        prompt_dropbox_access_code ;;
      4)
        prompt_dropbox_tokens ;;
      5)
        prompt_device_name ;;
      6)
        config_summary ;;
      7)
        prompt_save ;;
      8)
        config_done ;;
      *)
        configlevel=0
    esac
  done
}

# Run loop or configure
if [ -z "$1" ]; then
  configure
else
  if [ "$1" == "doloop" ]; then
    service_loop
  else
    printf "${color_normal}"
    printf "\nTo configure settigs, run this script without any command line arguments"
    printf "\nTo run the service, the first argument after the scriptname should be 'doloop'"
    printf "\n"
    exit 1
  fi
fi
