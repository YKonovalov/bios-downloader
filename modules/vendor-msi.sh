#!/bin/sh
# Please source common.sh before this file.

BIOS_DOWNLOAD_METHOD_MSI="$(echo $VENDOR|grep -i "^\(Micro-Star International\|MSI\)" >/dev/null && echo "msi_get_bios" || true)" #"
BIOS_DOWNLOAD_METHODREQS_MSI="msi-product-name"
if [ -z "$BIOS_DOWNLOAD_METHOD_MSI" ]; then
    unset BIOS_DOWNLOAD_METHOD_MSI
fi

msi_get_search_list(){
    (
    echo "$1"
    echo "$1"|tr '/' '\n'
    )|uniq|grep -v "^$"
}

msi_get_product_url(){
    local F="$1"
    local B="http://www.msi.com"
    grep '<h4><a href="/product/' "$F" |sed -n 's;.*<h4><a href="\(/product/[^"]\+\)".*;'$B'\1;p'
}

msi_get_bios_list(){
    html="$1"
    local version
    local down_type down_date down_file
    #local B="$(sed -n '/class="div-BIOS"/,/<div id="XXXX"/ p' "$html" | 
	#    sed -n  -e 's/.*class="bor_l \([^"]\+\)">\([^<]\+\)<.*/\1 \2/p' -e 's/.*class="bor_l \([^"]\+\)"><a href="\([^"]\+\)".*/\1 \2/p')" #'
    #debug "$B"
    # sed -n '1,/<\/td>/ {:a;N;/<\/td>/!ba;s/\n//gp}'
    local B="$(sed -n '/class="div-BIOS"/,/<div id="XXXX"/ p' "$html" |
                 sed -n  -e 's/.*class="bor_l \([^"]\+\)">\([^<]\+\)<.*/\1 \2/p' \
                     -e 's/.*class="bor_l \([^"]\+\)"><a href="\([^"]\+\)".*/\1 \2/p' \
                     -e '/.*class="bor_l down-note"[^>]*>/,/<\/td>/{:a;N;/<\/td>/!ba;s/\n/ /g;s/[[:blank:]]\+/ /g; s/.*class="bor_l down-note"[^>]*>\([^<]\+\)<.*/down-note \1/p}')" #'
    debug "$B"
    echo "$B"|grep '^down-version'|cat -b -|while read id tag version; do
	down_type="$(echo "$B"|grep '^down-type'|sed -n "$id,$id s/[a-z-]\+ //p")"
	down_date="$(echo "$B"|grep '^down-date'|sed -n "$id,$id s/[a-z-]\+ //p")"
	down_file="$(echo "$B"|grep '^down-file'|sed -n "$id,$id s/[a-z-]\+ //p")"
	down_note="$(echo "$B"|grep '^down-note'|sed -n "$id,$id s/[a-z-]\+ //p")"
	echo "$version $down_file $down_date $down_type	$down_note"
    done
}

msi_get_download_list(){
    local FILE="$1"
    grep 'href="http://download[[:digit:]].msi.com' "$FILE" |sed -n "s;.*href=\"\(http://download[[:digit:]].msi.com/[^\"]\+\)\".*;\1;p"|
	sort -u | while read url; do
	    name="${url##*/}"
	    if [ -n "$name" ]; then
		echo "$name	$url"
	    fi
	done
}

msi_get_bios(){
    local product_code=
    if [ -z "$msi_product_name" ]; then
	msi_product_name=$(cat /sys/class/dmi/id/product_name || sudo dmidecode -s system-product-name)
    fi
    msg "Product Name:	$msi_product_name"
    while read product_id; do
	msg "Searching for $product_id ..."
	curl --progress-bar -o "$temp_dir/search.html" "http://www.msi.com/service/search/?kw=$product_id&type=product" || doexit 1 "Failed to query for $product_id"
	msg "Done."
	product_url="$(msi_get_product_url "$temp_dir/search.html")"
	if [ -n "$product_url" ]; then
	    product_code="$product_id"
	    break
	fi
    done << PROD
$(msi_get_search_list "$msi_product_name")
PROD
    if [ -z "$product_code" ]; then
	doexit 2 "Search for $msi_product_name does not succeed."
    fi
    msg "Product Code: $product_code"
    msg "Requesting $product_url"
    curl --progress-bar -o "$temp_dir/prod.html" "$product_url" || doexit 3 "Failed to query for $product_code"
    bios_list="$(msi_get_bios_list "$temp_dir/prod.html")"
    if [ -z "$bios_list" ]; then
	doexit 4 "No BIOS update package found for $product_code"
    fi
    if [ -z "$list" ]; then
	info "--- available packages ---"
	info "$bios_list"
	info "--------------------------"
    else
	echo "$bios_list"
	exit
    fi
    if [ -z "$biosver" ]; then
	best="$(echo "$bios_list"|sort -r -k3|head -1)"
	bver="$(echo "$best"|awk '{print $1}')"
	msg "Best is $bver"
    else
	best="$(echo "$bios_list"|awk -v b="$biosver" '{if($1==b)print}'|head -1)"
	if [ -z "$best" ]; then
	    doexit 8 "BIOS update package version $biosver is not found"
	fi
	bver="$(echo "$best"|awk '{print $1}')"
	msg "Choosed $bver"
    fi
    down_url="http://www.msi.com$(echo "$best"|awk '{print $2}')"
    msg "Requesting $down_url"
    curl --progress-bar -o "$temp_dir/down.html" "$down_url" || doexit 5 "Failed to query $down_url"
    ok=
    while read filename url; do
	msg "Requesting $url"
	if curl --progress-bar -o "$DOWNLOAD_DIR/$filename" "$url"; then
	    doexit 0 "OK"
	fi
    done << DOWN
$(msi_get_download_list "$temp_dir/down.html")
DOWN
    doexit 7 "Failed to download BIOS update package"
}
