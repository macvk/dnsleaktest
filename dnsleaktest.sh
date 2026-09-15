#!/bin/sh
# DNS leak test client for bash.ws.
# Project: https://github.com/macvk/dnsleaktest
# SPDX-License-Identifier: MIT

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
error_code=1

interface=''
verbose=''
log_file=''
probes=30
parallel=30
short_output=0
watch_interval=''
program_name=${0##*/}

usage() {
    cat <<EOF
Usage: ${program_name} [OPTIONS]

Options:
  -i, --interface NAME|IP  Use a specific network interface
  -p, --probes NUMBER      Number of DNS probes to send (default: 30)
  -j, --parallel NUMBER    Maximum simultaneous probes (default: 30)
  -s, --short              Print a one-line result
  -w, --watch SECONDS      Repeat in short mode (minimum: 10 seconds)
  -v, --verbose LEVEL      Write diagnostics: info or trace
      --log-file FILE      Set the log path (implies --verbose info)
  -h, --help               Show this help
EOF
}

argument_error() {
    printf '%s\n' "$1" >&2
    printf "%s\n" "Try '${program_name} --help' for more information." >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -i|--interface)
            [ "$#" -ge 2 ] || argument_error "Option $1 requires a value."
            interface=$2
            shift 2
            ;;
        -v|--verbose)
            [ "$#" -ge 2 ] || argument_error "Option $1 requires info or trace."
            verbose=$2
            shift 2
            ;;
        -p|--probes)
            [ "$#" -ge 2 ] || argument_error "Option $1 requires a number."
            probes=$2
            shift 2
            ;;
        -j|--parallel)
            [ "$#" -ge 2 ] || argument_error "Option $1 requires a number."
            parallel=$2
            shift 2
            ;;
        -s|--short)
            short_output=1
            shift
            ;;
        -w|--watch)
            [ "$#" -ge 2 ] || argument_error "Option $1 requires a number of seconds."
            watch_interval=$2
            short_output=1
            shift 2
            ;;
        --log-file)
            [ "$#" -ge 2 ] || argument_error "Option --log-file requires a path."
            log_file=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            [ "$#" -eq 0 ] || argument_error "Unexpected argument: $1"
            ;;
        -*)
            argument_error "Unknown option: $1"
            ;;
        *)
            argument_error "Unexpected argument: $1"
            ;;
    esac
done

case "$verbose" in
    ''|info|trace)
        ;;
    *)
        argument_error "Invalid verbosity level '$verbose'; expected info or trace."
        ;;
esac

case "$probes" in
    ''|*[!0-9]*)
        argument_error "Invalid probe count '$probes'; expected an integer from 1 to 100."
        ;;
esac

if [ "$probes" -lt 1 ] || [ "$probes" -gt 100 ]; then
    argument_error "Invalid probe count '$probes'; expected an integer from 1 to 100."
fi

case "$parallel" in
    ''|*[!0-9]*)
        argument_error "Invalid parallel count '$parallel'; expected an integer from 1 to 100."
        ;;
esac

if [ "$parallel" -lt 1 ] || [ "$parallel" -gt 100 ]; then
    argument_error "Invalid parallel count '$parallel'; expected an integer from 1 to 100."
fi

if [ -n "$watch_interval" ]; then
    case "$watch_interval" in
        *[!0-9]*)
            argument_error "Invalid watch interval '$watch_interval'; expected at least 10 seconds."
            ;;
    esac

    if [ "$watch_interval" -lt 10 ]; then
        argument_error "Invalid watch interval '$watch_interval'; expected at least 10 seconds."
    fi
fi
[ -z "$log_file" ] || [ -n "$verbose" ] || verbose='info'

if [ -n "$verbose" ]; then
    if [ -z "$log_file" ]; then
        case "$(uname -s 2>/dev/null)" in
            Darwin)
                log_file="${HOME}/Library/Logs/dnsleaktest/dnsleaktest.log"
                ;;
            *)
                log_file="${XDG_STATE_HOME:-${HOME}/.local/state}/dnsleaktest/dnsleaktest.log"
                ;;
        esac
    fi

    log_dir=${log_file%/*}
    [ "$log_dir" = "$log_file" ] && log_dir='.'
    umask 077

    if ! mkdir -p "$log_dir" || ! : >> "$log_file" || ! chmod 600 "$log_file"; then
        argument_error "Cannot create diagnostic log: $log_file"
    fi

    if [ "${DNSLEAK_WATCH_CHILD:-0}" != 1 ]; then
        printf 'Diagnostic log: %s\n' "$log_file"
    fi
fi

log_info() {
    [ -z "$verbose" ] ||
        printf '%s [INFO] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$log_file"
}

log_trace() {
    [ "$verbose" != trace ] ||
        printf '%s [TRACE] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$log_file"
}

log_info "dnsleaktest started; OS=$(uname -s 2>/dev/null); interface=${interface:-default}; probes=$probes; parallel=$parallel"

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
    log_info "$1"
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
    log_info "ERROR: $1"
    log_info "dnsleaktest finished; exit=$error_code"
}

require_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo_error "Please, install \"$1\""
        exit "$error_code"
    fi
    increment_error_code
}

curl_request() {
    if [ "$verbose" = trace ]; then
        log_trace "curl request started"
        if [ -n "$interface" ]; then
            curl --verbose --interface "$interface" "$@" 2>> "$log_file"
        else
            curl --verbose "$@" 2>> "$log_file"
        fi
        status=$?
        log_trace "curl request finished; exit=$status"
        return "$status"
    fi
    if [ -n "$log_file" ] && [ -n "$interface" ]; then
        curl --interface "$interface" "$@" 2>> "$log_file"
    elif [ -n "$log_file" ]; then
        curl "$@" 2>> "$log_file"
    elif [ -n "$interface" ]; then
        curl --interface "$interface" "$@"
    else
        curl "$@"
    fi
}

ping_request() {
    if [ "$verbose" = trace ]; then
        trace_output=${probe_trace_file:-$log_file}
        printf '%s [TRACE] ping %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$trace_output"
    else
        trace_output=/dev/null
    fi
    if [ -n "$interface" ]; then
        if [ "$(uname -s 2>/dev/null)" = Darwin ]; then
            case "$interface" in
                *:*|*[0-9].[0-9]*)
                    ping -S "$interface" "$@" >> "$trace_output" 2>&1
                    ;;
                *)
                    ping -b "$interface" "$@" >> "$trace_output" 2>&1
                    ;;
            esac
        else
            ping -I "$interface" "$@" >> "$trace_output" 2>&1
        fi
    else
        ping "$@" >> "$trace_output" 2>&1
    fi
}

check_internet_connection() {
    log_info "Checking connectivity to ${api_domain}"
    if ! curl_request --silent --head --request GET "https://${api_domain}" | grep -q "200 OK"; then
        echo_error "No internet connection."
        exit "$error_code"
    fi
    increment_error_code
}

require_command curl
require_command ping
test_started=$(date +%s)
check_internet_connection

if command -v jq > /dev/null 2>&1; then
    jq_exists=1
else
    jq_exists=0
fi

id=$(curl_request --silent "https://${api_domain}/id")
log_info "Test ID received; bytes=${#id}"

i=1
active_probes=0

while [ "$i" -le "$probes" ]; do
    log_info "Starting DNS probe $i of $probes"

    if [ "$verbose" = trace ]; then
        probe_trace_file="${log_file}.probe-${i}.tmp" \
            ping_request -c 1 -W 1 "${i}.${id}.${api_domain}" > /dev/null 2>&1 &
    else
        ping_request -c 1 -W 1 "${i}.${id}.${api_domain}" > /dev/null 2>&1 &
    fi

    active_probes=$((active_probes + 1))

    if [ "$active_probes" -ge "$parallel" ]; then
        wait
        active_probes=0
    fi

    i=$((i + 1))
done

wait

if [ "$verbose" = trace ]; then
    i=1

    while [ "$i" -le "$probes" ]; do
        probe_trace_file="${log_file}.probe-${i}.tmp"

        if [ -f "$probe_trace_file" ]; then
            cat "$probe_trace_file" >> "$log_file"
            rm -f "$probe_trace_file"
        fi

        i=$((i + 1))
    done
fi

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
    log_info "Requesting JSON results"
    result_json=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?json")
else
    log_info "Requesting text results"
    result_txt=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?txt")
fi

dns_count=$(print_servers "dns" | wc -l | tr -d '[:space:]')

conclusion=$(print_servers "conclusion")

case "$conclusion" in
    *"not leaking"*|*"No leak"*|*"no leak"*)
        test_result='no_leak'
        ;;
    *"may be leaking"*|*"leak detected"*|*"Leak detected"*)
        test_result='leak_detected'
        ;;
    *)
        test_result='unknown'
        ;;
esac

if [ -n "$verbose" ]; then
    print_servers "ip" | while IFS= read -r detected_ip; do
        log_info "public_ip=$detected_ip"
    done

    print_servers "dns" | while IFS= read -r detected_dns; do
        log_info "dns_server=$detected_dns"
    done

    log_info "conclusion=$conclusion"
    log_info "result=$test_result"
fi

if [ "$short_output" -eq 1 ]; then
    test_finished=$(date +%s)
    printf '%s %ss %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$((test_finished - test_started))" "$test_result"
else
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
fi

log_info "dnsleaktest finished; dns_servers=$dns_count; exit=0"

if [ -z "$watch_interval" ]; then
    exit 0
fi

sleep "$watch_interval"

set -- -p "$probes" -j "$parallel" -w "$watch_interval"
[ -z "$interface" ] || set -- "$@" -i "$interface"
[ -z "$verbose" ] || set -- "$@" -v "$verbose"
[ -z "$log_file" ] || set -- "$@" --log-file "$log_file"

DNSLEAK_WATCH_CHILD=1
export DNSLEAK_WATCH_CHILD
exec "$0" "$@"
