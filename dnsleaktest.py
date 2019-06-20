#!/usr/bin/env python3
# encoding=utf-8
# Any questions: tutumbul@gmail.com
# https://bash.ws/dnsleak

import os
import subprocess
import json
from random import randint
from platform import system as system_name
from subprocess import call as system_call

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen


def ping(host):
    fn = open(os.devnull, 'w')
    param = '-n' if system_name().lower() == 'windows' else '-c'
    command = ['ping', param, '1', host]
    retcode = system_call(command, stdout=fn, stderr=subprocess.STDOUT)
    fn.close()
    return retcode == 0


leak_id = randint(1000000, 9999999)
for x in range(0, 10):
    ping('.'.join([str(x), str(leak_id), "bash.ws"]))

response = urlopen("https://bash.ws/dnsleak/test/"+str(leak_id)+"?json")
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
