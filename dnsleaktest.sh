#!/bin/sh
#usage:   ./dnsleaktest.sh [-i interface_ip|interface_name]
#example: ./dnsleaktest.sh -i eth1
#         ./dnsleaktest.sh -i 10.0.0.2

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
error_code=1

interface=''
while getopts "i:" opt; do
    case "$opt" in
        i) interface=$OPTARG ;;
        *) exit 2 ;;
    esac
done

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
}

if [ -z "$interface" ]; then
    :
else
    echo_bold "Interface: ${interface}"
    printf '\n'
fi

increment_error_code() {
    error_code=$((error_code + 1))
}

echo_error() {
    printf '%b\n' "${RED}${1}${NC}" >&2
}

require_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo_error "Please, install \"$1\""
        exit "$error_code"
    fi
    increment_error_code
}

curl_request() {
    if [ -n "$interface" ]; then
        curl --interface "$interface" "$@"
    else
        curl "$@"
    fi
}

ping_request() {
    if [ -n "$interface" ]; then
        ping -I "$interface" "$@"
    else
        ping "$@"
    fi
}

check_internet_connection() {
    if ! curl_request --silent --head --request GET "https://${api_domain}" | grep -q "200 OK"; then
        echo_error "No internet connection."
        exit "$error_code"
    fi
    increment_error_code
}

require_command curl
require_command ping
check_internet_connection

if command -v jq > /dev/null 2>&1; then
    jq_exists=1
else
    jq_exists=0
fi

id=$(curl_request --silent "https://${api_domain}/id")

i=1
while [ "$i" -le 10 ]; do
    ping_request -c 1 "${i}.${id}.${api_domain}" > /dev/null 2>&1
    i=$((i + 1))
done

is_blank() {
    case "$1" in
        *[![:space:]]*) return 1 ;;
        *) return 0 ;;
    esac
}

print_servers() {

    if [ "$jq_exists" -ne 0 ]; then

        printf '%s\n' "$result_json" | \
            jq  --monochrome-output \
            --raw-output \
            ".[] | select(.type == \"${1}\") | \"\(.ip)\(if .country_name != \"\" and  .country_name != false then \" [\(.country_name)\(if .asn != \"\" and .asn != false then \" \(.asn)\" else \"\" end)]\" else \"\" end)\""

    else

        printf '%s\n' "$result_txt" |
        while IFS= read -r line; do
            case "$line" in
                *"$1") ;;
                *) continue ;;
            esac

            ip=$(printf '%s\n' "$line" | cut -d'|' -f 1)
            country=$(printf '%s\n' "$line" | cut -d'|' -f 3)
            asn=$(printf '%s\n' "$line" | cut -d'|' -f 4)

            if is_blank "$ip"; then
                 continue
            fi

            if is_blank "$country"; then
                             printf '%s\n' "$ip"
            else
                 if is_blank "$asn"; then
                     printf '%s [%s]\n' "$ip" "$country"
                 else
                     printf '%s [%s, %s]\n' "$ip" "$country" "$asn"
                 fi
            fi
        done

    fi
}


if [ "$jq_exists" -ne 0 ]; then
    result_json=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?json")
else
    result_txt=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?txt")
fi

dns_count=$(print_servers "dns" | wc -l | tr -d '[:space:]')

echo_bold "Your IP:"
print_servers "ip"

printf '\n'
if [ "$dns_count" -eq 0 ]; then
    echo_bold "No DNS servers found"
else
    if [ "$dns_count" -eq 1 ]; then
        echo_bold "You use ${dns_count} DNS server:"
    else
        echo_bold "You use ${dns_count} DNS servers:"
    fi
    print_servers "dns"
fi

printf '\n'
echo_bold "Conclusion:"
print_servers "conclusion"

exit 0
