#!/bin/bash

#Text formatter
#Usage:echo "this is ${bold}bold${normal} but this isn't"
bold=$(tput bold)
normal=$(tput sgr0)

############### PARAM CHECK ##########

if [ $# -eq 0 ]; then
  echo "${bold}No arguments supplied. Exiting......"
  sleep 1
  exit 1
fi

############### XCODE DIR CHECK ##########

PROJECT_DIR=$1

#Check if the given directory is Xcode project directory
xcarray=(`find ${PROJECT_DIR} -maxdepth 1 -name "*.xcodeproj"`)
if [ ${#xcarray[@]} -gt 0 ]; then
  #found
  fileName=$(basename "${xcarray[0]}")     #gets `PROJECT`.xcodeproj
  nameWOextension=${fileName%.*}           #filters to `PROJECT`
  echo $nameWOextensio
else
  echo "${bold}Couldn't find the Xcode project. Exiting......"
  sleep 1
  exit 1
fi

############### ASK FOR DEV ID AND PASSWORD ##########
regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
echo -n "${bold}"APPLE_DEVELOPER_ID:
read ITC_USER

if [[ $ITC_USER =~ $regex ]] ; then
  echo ""
else
  echo "${bold}Improper Email Address. Exiting......"
  exit 1
fi

echo -n Password:
read -s ITC_PASSWORD

############### VAR INIT ##############

PROJECT_GLOBAL_NAME=$nameWOextension
PROJECT="${PROJECT_DIR}/${PROJECT_GLOBAL_NAME}.xcodeproj"
SCHEME=$PROJECT_GLOBAL_NAME

#Workspace may or may not exist
WORKSPACE="${PROJECT_DIR}/${PROJECT_GLOBAL_NAME}.xcworkspace"
INFOPLIST_FILE="Info.plist"

isPodUsed=false
############### CHECK IF POD IS USED OR NOT ##############
xcarray=(`find ${PROJECT_DIR} -maxdepth 1 -name "*.xcworkspace"`)
if [ ${#xcarray[@]} -gt 0 ]; then
  #Pods used
  isPodUsed=true
fi

############### CLEAN PROJ ############

#Clean the project at first
echo "${bold}Cleaning ${PROJECT_GLOBAL_NAME}"
if $isPodUsed; then
  xcodebuild clean -workspace $WORKSPACE -configuration Release -scheme $SCHEME
else
  xcodebuild clean -project $PROJECT -configuration Release -alltargets
fi
sleep 1
#Check if clean succeeded
if [ $? != 0 ]; then
exit 1
fi

echo "***********************"

############## BUMP BUILDNUMBER #########
#Bump the build number
_BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${PROJECT_GLOBAL_NAME}/${INFOPLIST_FILE}")
_BUILD_NUMBER=$(($_BUILD_NUMBER + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $_BUILD_NUMBER" "${PROJECT_DIR}/${PROJECT_GLOBAL_NAME}/${INFOPLIST_FILE}"
echo "${bold}** BUILD NUMBER SUCCESSFULLY BUMPED TO ${_BUILD_NUMBER} **${normal}"
sleep 1
echo "***********************"

############### ARCHIVE & GENERATE IPA #############
# Archive the project
_ARCHIVE_PATH="~/Desktop/${PROJECT_GLOBAL_NAME}.xcarchive"
if $isPodUsed; then
echo "xxx"
  xcodebuild archive -scheme $SCHEME -workspace $WORKSPACE -configuration Release -archivePath "${_ARCHIVE_PATH}"
else
echo "yyy"
  xcodebuild archive -scheme $SCHEME -project $PROJECT -configuration Release -archivePath "${_ARCHIVE_PATH}"
fi
#Check if archived
if [ $? != 0 ]; then
exit 1
fi
sleep 1

# Generate iPA file
# export method (app-store, ad-hoc, enterprise or development)
xcodebuild -exportArchive -archivePath "${_ARCHIVE_PATH}" -exportPath "~/Desktop/${PROJECT_GLOBAL_NAME}" -exportOptionsPlist "exportOptions.plist"
#Check if ipa generated
if [ $? != 0 ]; then
exit 1
fi

# Remove the .xcarchive file
cd ~/Desktop
rm -rf "${PROJECT_GLOBAL_NAME}.xcarchive"
#
## Uploading build
echo "${bold}***** Checking for upload......."
altool="$(dirname "$(xcode-select -p)")/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool"
ipa="~/Desktop/${PROJECT_GLOBAL_NAME}/${PROJECT_GLOBAL_NAME}.ipa"


######### UPLOAD BINAIRES#############

#ITC_USER="hkarmacharya@navyaata.com"
#ITC_PASSWORD="Lftechn0l0gy!@#"
time "$altool" --upload-app -f "$ipa" --username "$ITC_USER" --password "$ITC_PASSWORD"
