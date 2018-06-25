# dnsleaktest
DNS leak test shows your real DNS servers. If you were wondering what DNS servers is used by your system - this tool would show you. 
In the case of VPN or other privacy tool it would be a good idea to check if your DNS queries is not leaking outside your VPN.
                                                                                                           
## How to install & use                                                                                  

### Linux

1. Download dnsleaktest.py
```
wget https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.py
```

```
chmod +x dnsleaktest.py
```

2. Run dnsleaktest.py
```
./dnsleaktest.py
```

### Windows

1. Download dnsleaktest.bat

```
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.bat', 'dnsleaktest.bat') }"
```

2. Run dnsleaktest.bat
```
dnsleaktest.bat
```

### macOS

1. Download dnsleaktest.py

```
curl https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.py -o dnsleaktest.py
```

```
chmod +x dnsleaktest.py
```

2. Run dnsleaktest.py
```
./dnsleaktest.py
```