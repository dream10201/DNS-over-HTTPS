#!/bin/bash
FILE=doh.list
BLOCK_DNS=("dns.pub" "doh.360.cn" "dns.alidns.com" "doh.pub")

CHECK_LINK=("https://www.google.com/ncr" "https://www.10010.com" "https://www.qq.com" "https://www.baidu.com")

echo_err(){
    echo  -ne " \033[31m\xE2\x9D\x8C\033[0m"
}
echo_success(){
    echo -ne " \033[32m\xE2\x9C\x85\033[0m"
}
checkDoh() {
    local pids=()
    local fail=0
    for link in "${CHECK_LINK[@]}"; do
        (curl -sIS -m 9 --doh-url "$1" "${link}" &>/dev/null) &
        pids+=($!)
    done
    while [ ${#pids[@]} -gt 0 ]; do
        if ! wait -n; then
            fail=1
            break
        fi
        for i in "${!pids[@]}"; do
            if ! kill -0 "${pids[i]}" 2>/dev/null; then
                unset 'pids[i]'
            fi
        done
    done
    if [ "$fail" -eq 0 ]; then
        return 0
    else
        kill "${pids[@]}" &>/dev/null
        return 1
    fi
}


url_tmp=$(mktemp)
urls=$(curl -s "https://github.com/curl/curl/wiki/DNS-over-HTTPS" | grep -oP 'href="\Khttps://[^"]+')
urls+=" "
urls+=$(curl -s "https://adguard-dns.io/kb/zh-CN/general/dns-providers/" | grep -oP '<tr><td>DNS-over-HTTPS(.*?)</td><td><code>\Khttps://[^<]+')

urls=$(echo $urls | tr ' ' '\n' | grep -v "github" | sort -u | uniq)
for url in ${urls}; do
    domain=$(echo "$url" | awk -F/ '{print $3}')
    if [[ " ${BLOCK_DNS[*]} " == *" $domain "* ]]; then
        continue
    fi
    echo -n "$url"
    if ! checkDoh "$url"; then
        echo_err
        echo ""
        continue
    fi
    echo_success
    echo ""
    echo ${url%/} >>${url_tmp}
done
cat ${url_tmp} | sort | uniq >${FILE}
