#!/bin/sh
# Please source common.sh before this file.

BIOS_DOWNLOAD_METHOD_DELL="$(echo $VENDOR|grep -i "^Dell" >/dev/null && echo "dell_get_bios" || true)"
BIOS_DOWNLOAD_METHODREQS_DELL="dell-service-tag|dell-product-id"
if [ -z "$BIOS_DOWNLOAD_METHOD_DELL" ]; then
    unset BIOS_DOWNLOAD_METHOD_DELL
else
    DELL_STATS="$WDIR/DELL-PlatformID-stats.txt"
fi

dell_find_bioses(){
    local file="$1"
    grep Dell-BIOS "$file" |grep '^<a '| sed -n "s/.*AddToMyDownloadList(\('[^)]\+\)).*/\1/p"|awk -F, '{print $5" "$4" "$3}'|tr -d \'
}

dell_parse_bios_json(){
PARSE="$(cat <<EOF
import sys
import json
obj = json.load(sys.stdin)
for v in obj['AllDriverFormats']['Format']:
        print v['FileTypeDescription'],v['ProductCode'],v['DriverId'],obj['DellVersion'],v['HttpFileLocation'],v['FileFormatName']
EOF
)"
PYTHONIOENCODING=utf-8 python -c "$PARSE"
}

dell_choose_package(){
    local input="$1"
    local platform="${2:-$OS}"
    case $platform in
	GNU/Linux|Linux|linux)
		    debug "Platform: Linux"
		    native_match="LLXP"
		    preffered_match="BE,BEN,BEW,LWXP"
		    ;;
	Windows/Cygwin|Windows|windows)
		    debug "Platform: Windows"
		    native_match="LWXP,BEW"
		    preffered_match="BE,BEN"
		    ;;
	*)
		    native_match=""
		    preffered_match="BE,BEN,BEW,LWXP"
		    ;;
    esac
    input="$(cat -)"
    native="$(echo "$input"|awk -v mlist="$native_match" '{split(mlist,m,/,/);for(i in m)if($1==m[i]){print;next}}')"
    if [ -z "$native" ]; then
	if [ -n "$1" ]; then
	    doexit 4 "No matching BIOS update package found for specified platform $1"
	else
	    info "No native BIOS update packages for $platform found. Will try other options."
	fi
	others="$(echo "$input"|awk -v mlist="$preffered_match" '{split(mlist,m,/,/);for(i in m)if($1==m[i]){print;next}}')"
	if [ -z "$others" ]; then
	    doexit 5 "No suitable BIOS update package found"
	else
	    echo "$others"
	fi
    else
	echo "$native"
    fi
}

dell_get_bios(){
    if [ -z "$dell_product_id" ]; then
	if [ -z "$dell_service_tag" ]; then
	    dell_service_tag=$(sudo cat /sys/class/dmi/id/product_serial || sudo dmidecode -s system-serial-number)
	fi
	msg "Service Tag:	$dell_service_tag"
	msg "Validating Service Tag..."
	R="$(curl --progress-bar -d ServiceTagCode="$dell_service_tag" -d cache=false 'http://www.dell.com/support/home/us/en/555/ProductSelectorArea/PSSelect/SetSVCTag')"
	if echo "$R"|grep '"ResponseCode":0}$' >/dev/null; then
	    msg "Service tag is valid"
	else
	    doexit 1 "Could not validate Service Tag $dell_service_tag."
	fi

	msg "Requesting product info..."
	R="$(curl --progress-bar -o "$temp_dir/prod.html" -c "$temp_dir/cookies" -d SelectedTab=2 -d random="301" "http://www.dell.com/support/drivers/us/en/555/ServiceTag/$dell_service_tag")"
	IDprobe="$(sed -n 's;.*"/support/drivers/us/en/555/DriverDetails/Product/\([^?]\+\)?.*;\1;p' "$temp_dir/prod.html"|sort -u)" #"
	if [ $(echo "$IDprobe"|wc -l) -eq 1 ] && [ -n "$IDprobe" ]; then
	    dell_product_id=$IDprobe
	    msg "ProductID: $dell_product_id"
	else
	    debug "IDprobe: $IDprobe"
	fi

	BL="$(dell_find_bioses "$temp_dir/prod.html")"
	debug "BIOS List at ServiceTag: $BL"
	if [ -z "$BL" ]; then
	    msg "Requesting product info the alternate way..."
	    #R="$(curl -o "$temp_dir/drv-by-servicetag.html" -b "$temp_dir/cookies" -d tabIndex=0 -d retrieveState=false "http://www.dell.com/support/drivers/us/en/555/DriversHome/GetDriversBySelectedIndex")"
	    R="$(curl --progress-bar -o "$temp_dir/prod.html" -b "$temp_dir/cookies" -d tabIndex=1 -d retrieveState=false "http://www.dell.com/support/drivers/us/en/555/DriversHome/GetDriversBySelectedIndex")"
	    BL="$(dell_find_bioses "$temp_dir/prod.html")"
	    debug "BIOS List at Product: $BL"
	fi
    else
	msg "ProductID: $dell_product_id"
	msg "Requesting product info..."
	R="$(curl --progress-bar -o "$temp_dir/prod.html" -c "$temp_dir/cookies" "http://www.dell.com/support/drivers/us/en/555/Product/$dell_product_id")"
	BL="$(dell_find_bioses "$temp_dir/prod.html")"
    fi
    if [ -z "$list" ]; then
	debug "BIOS List at Product: $BL"
    else
	echo "$BL"
	exit
    fi
    if [ -z "$biosver" ]; then
	BEST_DRIVERID="$(echo "$BL"|head -1|awk '{print $3}')"
	if [ -n "$BEST_DRIVERID" ]; then
	    msg "DriverID: $BEST_DRIVERID"
	else
	    doexit 3 "Sorry no BIOS update found for  $dell_product_id $dell_service_tag"
	fi
    else
	BEST_DRIVERID="$(echo "$BL"|head -1|awk '{print $3}')"
	if [ -n "$BEST_DRIVERID" ]; then
	    msg "DriverID: $BEST_DRIVERID"
	else
	    doexit 3 "Sorry no BIOS update found for  $dell_product_id $dell_service_tag"
	fi
    fi
    curl --progress-bar -o "$temp_dir/bestdriverid.html" "http://www.dell.com/support/drivers/us/en/555/DriverDetails/Product/$dell_product_id?driverId=$BEST_DRIVERID"
    T="$(grep 'var modelData' "$temp_dir/bestdriverid.html" |tr -d '\r'|sed -e 's/.*var modelData = //' -e 's/;$//'|tee "$temp_dir/drv.json"|dell_parse_bios_json||mv "$temp_dir/drv.json" ./)"

    debug "All BIOS package formats: $T"
    preffered_platform=
    echo "$T"|dell_choose_package "$preffered_platform"|head -1| \
	while read packid platid driverid version url description; do
	    FILE="${url##*/}"
	    msg "------- choosed package type $packid ----"
	    msg "Version: $version"
	    msg " System: $platid"
	    msg "   Type: $description"
	    msg "   File: $FILE"
	    msg "-----------------------------------------"
	    [ -d "$DOWNLOAD_DIR" ] || mkdir -p "$DOWNLOAD_DIR" || doexit 6 "Could not create $DOWNLOAD_DIR"
	    info "Downloading $url"
	    curl --progress-bar -o "$DOWNLOAD_DIR/$FILE" "$url" || doexit 7 "Download failed"
	    msg "Download OK"
	done
}
