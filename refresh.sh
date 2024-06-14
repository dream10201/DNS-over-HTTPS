#!/bin/bash
FILE=doh.list
BLOCK_DNS=("dns.pub" "doh.360.cn" "dns.alidns.com" "doh.pub")
checkDoh() {
    if curl --connect-timeout 1 -m 2 --doh-url "$1" -v "https://www.google.com" 2>&1 | grep -q "was resolved."; then
        return 0
    else
        return 1
    fi
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
    echo $url >>${url_tmp}
done
cat ${url_tmp} | sort | uniq >${FILE}
