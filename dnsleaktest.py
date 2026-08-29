#!/usr/bin/env python3
# encoding=utf-8
# Any questions: tutumbul@gmail.com
# https://bash.ws/dnsleak

import os
import subprocess
import json
from concurrent.futures import ThreadPoolExecutor
from random import randint
from platform import system as system_name
from subprocess import call as system_call

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen


def ping(host):
    fn = open(os.devnull, 'w')
    current_system = system_name().lower()
    if current_system == 'windows':
        command = ['ping', '-n', '1', '-w', '1000', host]
    elif current_system == 'darwin':
        command = ['ping', '-c', '1', '-W', '1000', host]
    else:
        command = ['ping', '-c', '1', '-W', '1', host]
    retcode = system_call(command, stdout=fn, stderr=subprocess.STDOUT)
    fn.close()
    return retcode == 0


response = urlopen("https://bash.ws/id")
data = response.read().decode("utf-8")

leak_id = data
hosts = ('.'.join([str(x), leak_id, "bash.ws"]) for x in range(1, 31))
with ThreadPoolExecutor(max_workers=30) as executor:
    list(executor.map(ping, hosts))

response = urlopen("https://bash.ws/dnsleak/test/"+leak_id+"?json")
data = response.read().decode("utf-8")
parsed_data = json.loads(data)

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
