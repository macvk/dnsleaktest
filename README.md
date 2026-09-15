# DNS Leak Test

This tool reports your external IP address and the DNS servers used by your
connection. If their network providers differ unexpectedly, your DNS traffic
may be leaking outside the intended connection or VPN.

## Linux and macOS

### How to install and use the shell version

Please, before use make sure you have `curl` and `ping` installed.

1. Download `dnsleaktest.sh` from v1.4:

```sh
curl -fLO https://raw.githubusercontent.com/macvk/dnsleaktest/v1.4/dnsleaktest.sh
```

```sh
chmod +x dnsleaktest.sh
```

2. Run it:

```sh
./dnsleaktest.sh
```

### How to install and use the Python version

1. Download `dnsleaktest.py` from [v1.4](https://github.com/macvk/dnsleaktest/releases/tag/v1.4):

```sh
curl -fLO https://raw.githubusercontent.com/macvk/dnsleaktest/v1.4/dnsleaktest.py
```

```sh
chmod +x dnsleaktest.py
```

2. Run it:

```sh
./dnsleaktest.py
```

-----------------------------------------------------

## Windows

### How to install and use the batch file

1. Download dnsleaktest.bat

```powershell
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/macvk/dnsleaktest/v1.4/dnsleaktest.bat -OutFile dnsleaktest.bat
```

2. Run `dnsleaktest.bat`:

```bat
dnsleaktest.bat
```

-----------------------------------------------------

## Prebuilt Go executables

Version 1.4 executables are built by GitHub Actions and published on the
[v1.4 release page](https://github.com/macvk/dnsleaktest/releases/tag/v1.4).

### Linux

- [Linux amd64](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-linux-amd64)
- [Linux arm64](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-linux-arm64)
- [Linux ARMv7](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-linux-armv7)

After downloading the correct executable for your system:

```sh
chmod +x dnsleaktest-linux-amd64
./dnsleaktest-linux-amd64
```

### macOS

- [macOS Intel](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-darwin-amd64)
- [macOS Apple Silicon](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-darwin-arm64)

The macOS executables are unsigned. macOS may ask you to confirm that you want
to run a downloaded executable.

### Windows

- [Windows amd64](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-windows-amd64.exe)
- [Windows arm64](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-windows-arm64.exe)
- [Windows 32-bit](https://github.com/macvk/dnsleaktest/releases/download/v1.4/dnsleaktest-windows-386.exe)

Open Command Prompt, navigate to the download directory, and run the downloaded
executable.

### Build from source

Install Go, then select the target operating system and architecture. Examples:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o dnsleaktest-linux-amd64 dnsleaktest.go
GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -o dnsleaktest-darwin-arm64 dnsleaktest.go
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o dnsleaktest-windows-amd64.exe dnsleaktest.go
```

## How to run from Docker

### Linux

Use host networking so the test sees the host's network stack and DNS
configuration. This is important when the host uses a local DNS resolver such as
systemd-resolved or NextDNS.

```
docker run --rm --network host python:alpine sh -c 'wget -q -O- https://raw.githubusercontent.com/macvk/dnsleaktest/v1.4/dnsleaktest.py | python'
```

### macOS and Windows

Docker Desktop runs containers in a virtual machine, so host networking does not
provide the same view of the host's DNS configuration as it does on Linux. The
following command tests the DNS configuration visible inside the container:

```
docker run --rm python:alpine sh -c 'wget -q -O- https://raw.githubusercontent.com/macvk/dnsleaktest/v1.4/dnsleaktest.py | python'
```
