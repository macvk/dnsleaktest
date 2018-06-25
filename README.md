# dnsleaktest
DNS leak test shows your real DNS servers. If you were wondering what DNS servers is used by your system - this tool would show you. 
In the case of VPN or other privacy tool it would be a good idea to check if your DNS queries is not leaking outside your VPN.
                                                                                                           
## How to install & use                                                                                  

### Linux
```
wget https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.py
```

```
chmod +x dnsleaktest.py
```

```
./dnsleaktest.py
```

### Windows

```
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.bat', 'dnsleaktest.bat') }"
```

```
dnsleaktest.bat
```