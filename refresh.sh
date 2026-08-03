#!/bin/bash
FILE=doh.list
JOBS=10   # 同时检测的 DoH 服务器数量
BLOCK_DNS=("dns.pub" "doh.360.cn" "dns.alidns.com" "doh.pub")

CHECK_LINK=("https://www.google.com/ncr" "https://www.10010.com" "https://www.qq.com" "https://www.baidu.com")

url_tmp=$(mktemp)
src_tmp=$(mktemp)
trap 'rm -f "$url_tmp" "$src_tmp"' EXIT

# 所有测试站点均可通过该 DoH 访问才算可用,任一失败立即终止剩余检测
checkDoh() {
    local doh=$1 pids=()
    for link in "${CHECK_LINK[@]}"; do
        curl -sIS -m 9 --doh-url "$doh" "$link" &>/dev/null &
        pids+=("$!")
    done
    local remaining=${#pids[@]}
    while ((remaining > 0)); do
        if ! wait -n; then
            kill "${pids[@]}" 2>/dev/null
            wait "${pids[@]}" 2>/dev/null
            return 1
        fi
        ((remaining--))
    done
    return 0
}

# 检测单个 DoH 并输出结果行;可用的追加到 url_tmp
checkOne() {
    local url=$1
    if checkDoh "$url"; then
        echo "${url%/}" >>"$url_tmp"
        printf '%s \033[32m\xE2\x9C\x85\033[0m\n' "$url"
    else
        printf '%s \033[31m\xE2\x9D\x8C\033[0m\n' "$url"
    fi
}

# 并行抓取两个来源的 DoH 列表
curl -s "https://github.com/curl/curl/wiki/DNS-over-HTTPS" |
    grep -oP 'href="\Khttps://[^"]+' >>"$src_tmp" &
curl -s "https://adguard-dns.io/kb/zh-CN/general/dns-providers/" |
    grep -oP '<tr><td>DNS-over-HTTPS(.*?)</td><td><code>\Khttps://[^<]+' >>"$src_tmp" &
wait

mapfile -t urls < <(grep -v "github" "$src_tmp" | sort -u)
if ((${#urls[@]} == 0)); then
    echo "获取 DoH 服务器列表失败" >&2
    exit 1
fi

running=0
for url in "${urls[@]}"; do
    domain=${url#*://}
    domain=${domain%%/*}
    if [[ " ${BLOCK_DNS[*]} " == *" $domain "* ]]; then
        continue
    fi
    checkOne "$url" &
    if ((++running >= JOBS)); then
        wait -n
        ((running--))
    fi
done
wait

sort -u "$url_tmp" >"$FILE"
