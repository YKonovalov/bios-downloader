#!/bin/sh
# Please source common.sh before this file.

BIOS_DOWNLOAD_METHOD_SAMSUNG="$(echo $VENDOR|grep -i "^Samsung" >/dev/null && echo "get_bios_samsung" || true)"
BIOS_DOWNLOAD_METHODREQS_SAMSUNG="current-bios-version|samsung-platform-id"
if [ -z "$BIOS_DOWNLOAD_METHOD_SAMSUNG" ]; then
    unset BIOS_DOWNLOAD_METHOD_SAMSUNG
fi
SAMSUNG_STATS="$WDIR/Samsung-PlatformID-stats.txt"

request_file_by_platform_id(){
    local PlatformID="$1"
    local URL="http://sbuservice.samsungmobile.com/BUWebServiceProc.asmx/GetContents?platformID=$PlatformID&PartNumber=AAAA"
    msg "Samsung PlatformID:	$PlatformID"
    info "Requesting $URL"
    local RESPONSE="$(curl -f $URL)"
    local FILE=$(echo "$RESPONSE"|tr -d '\r'|sed -n "s/<FilePathName>\(.*\)<\/FilePathName>/\1/p"|tr -d '[[:blank:]]') #"
    if [ -z "$FILE" ]; then
	info "No file given in response."
	return 2
    else
	echo "$FILE"
    fi
}

append_platformid_list(){
    local PlatformID="$1"
    if echo "$PlatformID_LIST"|grep "^$PlatformID$" >/dev/null; then
	debug "Skipping PlatformID:	$PlatformID"
    else
	debug "Adding PlatformID:	$PlatformID"
	PlatformID_LIST="$(printf "%s\n%s\n" "$PlatformID_LIST" "$PlatformID"|uniq)"
    fi
}

get_platformid_by_bios_version(){
    local PlatformID_LIST=
    # Platform ID is samsung specific magic. Seems like the only chance to get it is BIOS VERSION
    # We take only first word if there are any dots in BIOS version.
    BIOSVER=${current_bios_version%%.*}
    debug "Effective BIOS Version: $BIOSVER"
    BIOSVER_CHARS="$(echo "$BIOSVER"|awk '{print length($1)}')"
    debug "BIOS Version length: $BIOSVER_CHARS"
    if [ -f "$SAMSUNG_STATS" ]; then
	debug "We have Samsung PlatformID stats file. Using it."
	while read count pchars bchars calc biosv platid; do
	    info "Trying PlatformID calc scheme $pchars-$bchars-$calc"
	    case $calc in
		normal)
			PlatformID=$(echo "$BIOSVER"|sed "s/./&\n/g"|grep -v '^$'|tail -n $pchars|tr -d '\n')
			;;
		zerohack)
			PlatformID="0$(echo "$BIOSVER"|sed "s/./&\n/g"|grep -v '^$'|tail -n $((pchars-1))|tr -d '\n')"
			;;
		*)
			PlatformID="$platid"
			;;
	    esac
	    #Adding stats-based IDs
	    append_platformid_list "$PlatformID"
	done << STATS
$(awk -v b=$BIOSVER_CHARS '{if(($3==b)&&($1>6))print}' "$SAMSUNG_STATS")
STATS
#'
    else
	warning "Samsung PlatformID stats file is unaccessible. Please run samsung-platformid-stats to generate $SAMSUNG_STATS."
    fi
    # Adding simple method ID
    PlatformID=${BIOSVER:$((BIOSVER_CHARS/2))}
    append_platformid_list "$PlatformID"

    echo "$(echo $PlatformID_LIST)"
}

get_bios_samsung(){
    if [ -z "$samsung_platform_id" ]; then
	if [ -z "$current_bios_version" ]; then
	    current_bios_version=$(cat /sys/class/dmi/id/bios_version || sudo dmidecode -s bios-version)
	fi
	msg "Current BIOS Version:	$current_bios_version"
	samsung_platform_id="$(get_platformid_by_bios_version $current_bios_version)"
    fi

    for PlatformID in $samsung_platform_id; do
	FILE=$(request_file_by_platform_id "$PlatformID"||true)
	if [ -n "$FILE" ]; then
	    break
	fi
    done

    if [ -z "$FILE" ]; then
        doexit 5 "BIOS update package is not found. Sorry."
    fi

    msg "File to download:	$FILE"

    FILE_URL="http://sbuservice.samsungmobile.com/upload/BIOSUpdateItem/$FILE"

    msg "URL: $FILE_URL"

    [ -d "$DOWNLOAD_DIR" ] || mkdir -p "$DOWNLOAD_DIR" || (echo "Could not create $DOWNLOAD_DIR"; exit 1 )
    if [ -f "$DOWNLOAD_DIR/$FILE" ] && [ -z "$force" ]; then
	warning "Already there: $DOWNLOAD_DIR/$FILE . Will not download unless --force is specified."
    else
	msg "Downloading $FILE"
	curl --progress-bar -o "$DOWNLOAD_DIR/$FILE" "$FILE_URL" || (echo Download failed; exit 2)
	if [ $? -eq 0 ]; then
	    break
	fi
	msg "Download OK"
    fi
}
