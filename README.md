# dnsleaktest
Are your DNS queries not leaking outside your VPN? Do you know your external IP? Do you know your ASN? The test will show you.
                                                                                                           
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