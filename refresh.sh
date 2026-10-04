#!/bin/bash
FILE=doh.list
JOBS=20   # 同时检测的 DoH 服务器数量
BLOCK_DNS=("dns.pub" "doh.360.cn" "dns.alidns.com" "doh.pub")

CHECK_LINK=("https://www.google.com/ncr" "https://store.steampowered.com" "https://github.com" "https://www.baidu.com")

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
        echo "$url" >>"$url_tmp"
        printf '%s \033[32m\xE2\x9C\x85\033[0m\n' "$url"
    else
        printf '%s \033[31m\xE2\x9D\x8C\033[0m\n' "$url"
    fi
}

# 从 DNSCrypt stamp 中解析出普通 DoH(协议 0x02)地址
decodeStamps() {
    python3 -c '
import sys, base64
for line in sys.stdin:
    s = line.strip()[7:]
    b = base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))
    if b[0] != 2:
        continue
    i = 9
    i += 1 + b[i]
    while b[i] & 0x80:
        i += 1 + (b[i] & 0x7f)
    i += 1 + b[i]
    host = b[i + 1:i + 1 + b[i]].decode()
    i += 1 + b[i]
    print("https://" + host + b[i + 1:i + 1 + b[i]].decode())
'
}

# 并行抓取各来源的 DoH 列表
curl -fsSL -m 30 "https://github.com/curl/curl/wiki/DNS-over-HTTPS" |
    grep -oP 'href="\K(https://[^"]+)(?="[^>]*>\1</a>)' >>"$src_tmp" &
curl -fsSL -m 30 "https://adguard-dns.io/kb/zh-CN/general/dns-providers/" |
    grep -oP 'DNS-over-HTTPS(</td>)?<td><code>\Khttps://[^<]+' >>"$src_tmp" &
curl -fsSL -m 30 "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md" |
    grep '^sdns://Ag' | decodeStamps >>"$src_tmp" &
wait

mapfile -t urls < <(grep -v "github" "$src_tmp" | sed 's#/$##' | sort -u)
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
