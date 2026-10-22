#!/bin/sh
# DNS leak test client for bash.ws.
# Project: https://github.com/macvk/dnsleaktest
# SPDX-License-Identifier: MIT

version='1.5.0'

quote_argument() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

usage() {
    cat <<EOF
Usage: ${program_name} [OPTIONS]

Options:
  -i, --interface NAME|IP  Use a specific network interface
  -p, --probes NUMBER      Number of DNS probes to send (default: 30)
  -j, --parallel NUMBER    Maximum simultaneous probes (default: 30)
  -s, --short              Print a one-line result
  -w, --watch [SECONDS]    Repeat in short mode (default: 0 seconds)
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

log_info() {
    [ -z "$verbose" ] ||
        printf '%s [INFO] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$log_file"
}

log_trace() {
    [ "$verbose" != trace ] ||
        printf '%s [TRACE] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$log_file"
}

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
    log_info "$1"
}

print_line() {
    printf '%s\n' "$1"
    log_info "$1"
}

print_server_lines() {
    print_servers "$1" | while IFS= read -r output_line; do
        print_line "$output_line"
    done
}

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

is_blank() {
    case "$1" in
        *[![:space:]]*) return 1 ;;
        *) return 0 ;;
    esac
}

print_servers() {

    if [ "$jq_exists" -ne 0 ]; then

        printf '%s\n' "$result_json" | \
            jq --monochrome-output \
            --raw-output \
            ".[] | select(.type == \"${1}\") | . as \$record | [\$record.city_name, \$record.region_name, \$record.country_name, \$record.asn] | map(select(. != null and . != false and . != \"\")) as \$location | \"\(\$record.ip)\(if (\$location | length) > 0 then \" [\(\$location | join(\", \"))]\" else \"\" end)\""

    else

        printf '%s\n' "$result_txt" |
        while IFS= read -r line; do
            ip=$(printf '%s\n' "$line" | cut -d'|' -f 1)
            record_type=$(printf '%s\n' "$line" | cut -d'|' -f 5)
            city=$(printf '%s\n' "$line" | cut -d'|' -f 6)
            region=$(printf '%s\n' "$line" | cut -d'|' -f 7)
            country=$(printf '%s\n' "$line" | cut -d'|' -f 3)
            asn=$(printf '%s\n' "$line" | cut -d'|' -f 4)

            if [ "$record_type" != "$1" ]; then
                continue
            fi

            if is_blank "$ip"; then
                continue
            fi

            location=''

            for value in "$city" "$region" "$country" "$asn"; do
                if is_blank "$value"; then
                    continue
                fi

                if [ -n "$location" ]; then
                    location="${location}, ${value}"
                else
                    location=$value
                fi
            done

            if [ -n "$location" ]; then
                printf '%s [%s]\n' "$ip" "$location"
            else
                printf '%s\n' "$ip"
            fi
        done

    fi
}

program_name=${0##*/}
command_line=$(quote_argument "$program_name")

for argument
do
    command_line="${command_line} $(quote_argument "$argument")"
done

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
            watch_interval=0
            short_output=1
            shift

            if [ "$#" -gt 0 ]; then
                case "$1" in
                    -*) ;;
                    *) watch_interval=$1; shift ;;
                esac
            fi
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
            argument_error "Invalid watch interval '$watch_interval'; expected a non-negative integer."
            ;;
    esac
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

log_info "${program_name} version ${version} started; OS=$(uname -s 2>/dev/null); interface=${interface:-default}; probes=$probes; parallel=$parallel"
log_info "Command line: ${command_line}"

if [ -z "$interface" ]; then
    :
else
    echo_bold "Interface: ${interface}"
    printf '\n'
fi

require_command curl
require_command ping
test_started=$(date +%s)
check_internet_connection

if command -v jq > /dev/null 2>&1; then
    jq_exists=1
else
    jq_exists=0
fi

if ! id=$(curl_request --silent "https://${api_domain}/id"); then
    echo_error "Unable to obtain a test ID from ${api_domain}."
    exit "$error_code"
fi

if [ -z "$id" ]; then
    echo_error "Received an empty test ID from ${api_domain}."
    exit "$error_code"
fi

log_info "Test ID received; bytes=${#id}"
increment_error_code

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

if [ "$jq_exists" -ne 0 ]; then
    log_info "Requesting JSON results"

    if ! result_json=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?json=2"); then
        echo_error "Unable to retrieve DNS leak test results."
        exit "$error_code"
    fi

    result_error=$(printf '%s\n' "$result_json" | jq --raw-output '[.[] | select(.type == "error")][0].text // empty')

    if [ -n "$result_error" ]; then
        echo_error "$result_error"
        exit "$error_code"
    fi
else
    log_info "Requesting text results"

    if ! result_txt=$(curl_request --silent "https://${api_domain}/dnsleak/test/${id}?txt=2"); then
        echo_error "Unable to retrieve DNS leak test results."
        exit "$error_code"
    fi
fi

dns_count=$(print_servers "dns" | wc -l | tr -d '[:space:]')

conclusion=$(print_servers "conclusion")

if [ "$verbose" = trace ]; then
    if [ "$jq_exists" -ne 0 ]; then
        log_trace "Parsed JSON result:"
    else
        log_trace "Parsed text result:"
    fi

    print_servers "ip" | while IFS= read -r detected_ip; do
        log_trace "public_ip=$detected_ip"
    done

    print_servers "dns" | while IFS= read -r detected_dns; do
        log_trace "dns_server=$detected_dns"
    done

    log_trace "conclusion=$conclusion"
fi

if [ "$short_output" -eq 1 ]; then
    test_finished=$(date +%s)
    [ -n "$conclusion" ] || conclusion='Unknown'
    print_line "$(date '+%Y-%m-%dT%H:%M:%S%z') $((test_finished - test_started))s $conclusion"
else
    echo_bold "Your IP:"
    print_server_lines "ip"

    printf '\n'
    if [ "$dns_count" -eq 0 ]; then
        echo_bold "No DNS servers found"
    else
        if [ "$dns_count" -eq 1 ]; then
            echo_bold "You use ${dns_count} DNS server:"
        else
            echo_bold "You use ${dns_count} DNS servers:"
        fi
        print_server_lines "dns"
    fi

    printf '\n'
    echo_bold "Conclusion:"
    print_server_lines "conclusion"
fi

log_info "dnsleaktest finished; dns_servers=$dns_count; exit=0"

if [ -z "$watch_interval" ]; then
    exit 0
fi

if [ "$watch_interval" -ne 0 ]; then
    sleep "$watch_interval"
fi

set -- -p "$probes" -j "$parallel" -w "$watch_interval"
[ -z "$interface" ] || set -- "$@" -i "$interface"
[ -z "$verbose" ] || set -- "$@" -v "$verbose"
[ -z "$log_file" ] || set -- "$@" --log-file "$log_file"

DNSLEAK_WATCH_CHILD=1
export DNSLEAK_WATCH_CHILD
exec "$0" "$@"
