#!/usr/bin/env python3
# encoding=utf-8
# DNS leak test client for bash.ws.
# Project: https://github.com/macvk/dnsleaktest
# SPDX-License-Identifier: MIT

import os
import subprocess
import json
import argparse
import datetime
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from platform import system as system_name

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen


def parse_args():
    program_name = os.path.basename(sys.argv[0])
    parser = argparse.ArgumentParser(
        prog=program_name,
        description="Test the active connection for DNS leaks.")
    parser.add_argument('-i', '--interface', metavar='NAME|IP', help='use a specific network interface')
    parser.add_argument('-p', '--probes', metavar='NUMBER', type=probe_count, default=30,
                        help='number of DNS probes to send (default: 30)')
    parser.add_argument('-j', '--parallel', metavar='NUMBER', type=parallel_count, default=30,
                        help='maximum simultaneous probes (default: 30)')
    parser.add_argument('-s', '--short', action='store_true', help='print a one-line result')
    parser.add_argument('-w', '--watch', metavar='SECONDS', type=watch_interval,
                        help='repeat in short mode (minimum: 10 seconds)')
    parser.add_argument('-v', '--verbose', choices=('info', 'trace'), help='write diagnostics: info or trace')
    parser.add_argument('--log-file', metavar='FILE', help='set the log path (implies --verbose info)')
    return parser.parse_args()


def probe_count(value):
    try:
        count = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError('must be an integer from 1 to 100')

    if count < 1 or count > 100:
        raise argparse.ArgumentTypeError('must be an integer from 1 to 100')

    return count


def parallel_count(value):
    try:
        count = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError('must be an integer from 1 to 100')

    if count < 1 or count > 100:
        raise argparse.ArgumentTypeError('must be an integer from 1 to 100')

    return count


def watch_interval(value):
    try:
        seconds = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError('must be an integer of at least 10')

    if seconds < 10:
        raise argparse.ArgumentTypeError('must be an integer of at least 10')

    return seconds


def default_log_file():
    home = os.path.expanduser('~')
    current_system = system_name().lower()

    if current_system == 'darwin':
        return os.path.join(home, 'Library', 'Logs', 'dnsleaktest', 'dnsleaktest.log')

    if current_system == 'windows':
        local_app_data = os.environ.get(
            'LOCALAPPDATA', os.path.join(home, 'AppData', 'Local'))
        return os.path.join(local_app_data, 'dnsleaktest', 'dnsleaktest.log')

    return os.path.join(os.environ.get('XDG_STATE_HOME', os.path.join(home, '.local', 'state')),
                        'dnsleaktest', 'dnsleaktest.log')


class DiagnosticLog(object):
    def __init__(self, level, path):
        self.level, self.file = level, None
        self.lock = threading.Lock()
        if level:
            directory = os.path.dirname(path) or '.'
            if not os.path.isdir(directory):
                os.makedirs(directory)
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
            os.chmod(path, 0o600)
            self.file = os.fdopen(descriptor, 'a')
            if os.environ.get('DNSLEAK_WATCH_CHILD') != '1':
                print("Diagnostic log: " + path)

    def write(self, level, message):
        if self.file:
            stamp = datetime.datetime.now().astimezone().isoformat()

            with self.lock:
                self.file.write("{} [{}] {}\n".format(stamp, level, message))
                self.file.flush()

    def info(self, message):
        self.write('INFO', message)

    def trace(self, message):
        if self.level == 'trace':
            self.write('TRACE', message)


def ping(host, interface, diagnostic_log, probe, total_probes):
    current_system = system_name().lower()
    if current_system == 'windows':
        command = ['ping', '-n', '1', '-w', '1000', host]
    elif current_system == 'darwin':
        command = ['ping', '-c', '1', '-W', '1000', host]
    else:
        command = ['ping', '-c', '1', '-W', '1', host]
    if interface:
        if current_system == 'windows':
            command[1:1] = ['-S', interface]
        elif current_system == 'darwin':
            command[1:1] = ['-S' if (':' in interface or interface.replace('.', '').isdigit()) else '-b', interface]
        else:
            command[1:1] = ['-I', interface]
    diagnostic_log.info("Starting DNS probe {} of {}".format(
        probe, total_probes))
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = process.communicate()[0].decode('utf-8', errors='replace')
    diagnostic_log.trace("Command: {}\n{}".format(' '.join(command), output))
    diagnostic_log.info("DNS probe {} finished; exit={}".format(probe, process.returncode))
    return process.returncode == 0


def get_content(url, interface, diagnostic_log):
    safe_url = url.split('/dnsleak/test/')[0] + '/dnsleak/test/[REDACTED]' if '/dnsleak/test/' in url else url
    diagnostic_log.info("HTTP GET " + safe_url)
    if interface or diagnostic_log.level == 'trace':
        command = ['curl', '--silent', '--show-error', '--fail']
        if diagnostic_log.level == 'trace':
            command.append('--verbose')
        if interface:
            command.extend(['--interface', interface])

        command.append(url)
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = process.communicate()
        diagnostic_log.trace(error.decode('utf-8', errors='replace'))
        if process.returncode:
            message = error.decode('utf-8', errors='replace').strip()
            raise RuntimeError(message)

        diagnostic_log.info("HTTP request finished; bytes={}".format(len(output)))
        return output.decode('utf-8')

    response = urlopen(url)
    data = response.read()
    diagnostic_log.info("HTTP request finished; status={}; bytes={}".format(response.getcode(), len(data)))
    return data.decode('utf-8')


args = parse_args()
if args.watch:
    args.short = True
if args.log_file and not args.verbose:
    args.verbose = 'info'
diagnostic_log = DiagnosticLog(args.verbose, args.log_file or default_log_file())


def log_uncaught_exception(kind, value, traceback):
    diagnostic_log.info("ERROR: {}".format(value))
    diagnostic_log.info("dnsleaktest finished; exit=1")
    sys.__excepthook__(kind, value, traceback)


sys.excepthook = log_uncaught_exception
diagnostic_log.info("dnsleaktest started; OS={}; interface={}; probes={}; parallel={}".format(
    system_name(), args.interface or 'default', args.probes, args.parallel))
test_started = time.monotonic()

data = get_content("https://bash.ws/id", args.interface, diagnostic_log)

leak_id = data
with ThreadPoolExecutor(max_workers=min(args.probes, args.parallel)) as executor:
    futures = [executor.submit(ping, '.'.join([str(x), leak_id, "bash.ws"]),
                               args.interface, diagnostic_log, x, args.probes)
               for x in range(1, args.probes + 1)]
    [future.result() for future in futures]

data = get_content("https://bash.ws/dnsleak/test/"+leak_id+"?json", args.interface, diagnostic_log)
parsed_data = json.loads(data)
test_result = 'unknown'

for entry in parsed_data:
    if entry['type'] == 'ip':
        diagnostic_log.info("public_ip={}; country={}; asn={}".format(
            entry['ip'], entry['country_name'], entry['asn']))
    elif entry['type'] == 'dns':
        diagnostic_log.info("dns_server={}; country={}; asn={}".format(
            entry['ip'], entry['country_name'], entry['asn']))
    elif entry['type'] == 'conclusion':
        conclusion = entry['ip']
        diagnostic_log.info("conclusion={}".format(conclusion))
        conclusion_lower = conclusion.lower()
        if 'not leaking' in conclusion_lower or 'no leak' in conclusion_lower:
            test_result = 'no_leak'
        elif 'may be leaking' in conclusion_lower or 'leak detected' in conclusion_lower:
            test_result = 'leak_detected'

        diagnostic_log.info("result={}".format(test_result))

if args.short:
    servers = sum(1 for entry in parsed_data if entry['type'] == 'dns')
    elapsed = time.monotonic() - test_started
    timestamp = datetime.datetime.now().astimezone().isoformat(timespec='seconds')
    print("{} {:.2f}s {}".format(timestamp, elapsed, test_result))
    diagnostic_log.info("dnsleaktest finished; dns_servers={}; exit=0".format(servers))

    if not args.watch:
        raise SystemExit(0)

    try:
        time.sleep(args.watch)
    except KeyboardInterrupt:
        diagnostic_log.info("dnsleaktest finished; exit=130")
        raise SystemExit(130)

    arguments = [sys.executable, sys.argv[0], '-p', str(args.probes),
                 '-j', str(args.parallel), '-w', str(args.watch)]

    if args.interface:
        arguments.extend(['-i', args.interface])
    if args.verbose:
        arguments.extend(['-v', args.verbose])
    if args.log_file:
        arguments.extend(['--log-file', args.log_file])

    os.environ['DNSLEAK_WATCH_CHILD'] = '1'
    os.execv(sys.executable, arguments)

print("Your IP:")
for dns_server in parsed_data:
    if dns_server['type'] == "ip":
        if dns_server['country_name']:
            if dns_server['asn']:
                print(dns_server['ip']+" ["+dns_server['country_name']+", " +
                      dns_server['asn']+"]")
            else:
                print(dns_server['ip']+" ["+dns_server['country_name']+"]")
        else:
            print(dns_server['ip'])

servers = 0
for dns_server in parsed_data:
    if dns_server['type'] == "dns":
        servers = servers + 1

if servers == 0:
    print("No DNS servers found")
else:
    print("You use "+str(servers)+" DNS servers:")
    for dns_server in parsed_data:
        if dns_server['type'] == "dns":
            if dns_server['country_name']:
                if dns_server['asn']:
                    print(dns_server['ip']+" ["+dns_server['country_name'] +
                          ", " + dns_server['asn']+"]")
                else:
                    print(dns_server['ip']+" ["+dns_server['country_name']+"]")
            else:
                print(dns_server['ip'])

print("Conclusion:")
for dns_server in parsed_data:
    if dns_server['type'] == "conclusion":
        if dns_server['ip']:
            print(dns_server['ip'])

diagnostic_log.info("dnsleaktest finished; dns_servers={}; exit=0".format(servers))
