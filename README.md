# Dns Leak Test
The test shows DNS leaks and your external IP. If you use the same ASN for DNS and connection - you have no leak, otherwise here might be a problem.
                                                                                                           
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