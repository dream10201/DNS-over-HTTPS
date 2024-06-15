#!/bin/bash
FILE=doh.list
BLOCK_DNS=("dns.pub" "doh.360.cn" "dns.alidns.com" "doh.pub")

CHECK_LINK=("https://www.google.com/ncr" "https://x.com" "https://www.facebook.com" "https://www.youtube.com")
checkDoh() {
    local i=0
    for link in "${CHECK_LINK[@]}"; do
        curl -sS --connect-timeout 5 -m 5 -v --doh-url "$1" "${link}" &>/dev/null || ((i++))
    done
    if [[ "${i}" -gt 0 ]]; then
        return 1
    fi
    return 0
}
url_tmp=$(mktemp)
urls=$(curl -s "https://github.com/curl/curl/wiki/DNS-over-HTTPS" | grep -oP 'href="\Khttps://[^"]+')
urls+=" "
urls+=$(curl -s "https://adguard-dns.io/kb/zh-CN/general/dns-providers/" | grep -oP '<tr><td>DNS-over-HTTPS(.*?)</td><td><code>\Khttps://[^<]+')

urls=$(echo $urls | tr ' ' '\n' | sort -u | tr '\n' ' ')
for url in ${urls}; do
    domain=$(echo "$url" | awk -F/ '{print $3}')
    if [[ " ${BLOCK_DNS[*]} " == *" $domain "* ]]; then
        continue
    fi
    if ! checkDoh "$url"; then
        continue
    fi
    echo $url
    echo $url >>${url_tmp}
done
cat ${url_tmp} | sort | uniq >${FILE}
