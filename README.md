# Dns Leak Test
The test shows DNS leaks and your external IP. If you use the same ASN for DNS and connection - you have no leak, otherwise here might be a problem.
                                                                                                           
## How to install & use Python Version                                                                                  

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


-----------------------------------------------------

## How to build & use Golang Version                                                                                  

1. Download executable binary for Linux, MacOs or Windows without build:

### Linux

1. Download [dnsleaktest](https://www.dropbox.com/s/aarf10zls3xvu6z/dnsleaktest?dl=0)

```
chmod +x dnsleaktest
```

2. Run dnsleaktest
```
./dnsleaktest
```

### Windows

1. Download [dnsleaktest.exe](https://www.dropbox.com/s/ubee3tp3c41owcj/dnsleaktest.exe?dl=0)

2. Run dnsleaktest.exe, 
open cmd then navigate to the exe file  
```
dnsleaktest.exe
```

### macOS

1. Download [dnsleaktest](https://www.dropbox.com/s/aarf10zls3xvu6z/dnsleaktest?dl=0)

```
chmod +x dnsleaktest
```

2. Run dnsleaktest
```
./dnsleaktest
```

### Or build binaries in your machine 

1. Linux 
```
GOOS=linux GOARCH=386 go build -o dnsleaktest dnsleaktest.go

```
2. MacOS

```
GOOS=linux GOARCH=386 go build -o dnsleaktest dnsleaktest.go
```
3. Windows

```
GOOS=windows GOARCH=386 go build -o dnsleaktest.exe dnsleaktest.go

```