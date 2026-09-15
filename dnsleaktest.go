// DNS leak test client for bash.ws.
// Project: https://github.com/macvk/dnsleaktest
// SPDX-License-Identifier: MIT

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
)

var ApiDomain = "bash.ws"
var httpClient = &http.Client{Timeout: 30 * time.Second}
var diagnosticLogger *log.Logger
var verboseLevel string

type Block struct {
	Ip          string `json:"ip"`
	Country     string `json:"country"`
	CountryName string `json:"country_name"`
	Asn         string `json:"asn"`
	Type        string `json:"type"`
}

func raiseError(err error) {
	if err == nil {
		return
	}

	logInfo("ERROR: %v", err)
	logInfo("dnsleaktest finished; exit=1")
	panic(err)
}

func defaultLogFile() string {
	home, _ := os.UserHomeDir()

	if runtime.GOOS == "darwin" {
		return filepath.Join(home, "Library", "Logs", "dnsleaktest", "dnsleaktest.log")
	}

	if runtime.GOOS == "windows" {
		localAppData := os.Getenv("LOCALAPPDATA")

		if localAppData == "" {
			localAppData = filepath.Join(home, "AppData", "Local")
		}

		return filepath.Join(localAppData, "dnsleaktest", "dnsleaktest.log")
	}

	state := os.Getenv("XDG_STATE_HOME")

	if state == "" {
		state = filepath.Join(home, ".local", "state")
	}

	return filepath.Join(state, "dnsleaktest", "dnsleaktest.log")
}

func logInfo(format string, values ...interface{}) {
	if diagnosticLogger != nil {
		diagnosticLogger.Printf("[INFO] "+format, values...)
	}
}

func logTrace(format string, values ...interface{}) {
	if diagnosticLogger != nil && verboseLevel == "trace" {
		diagnosticLogger.Printf("[TRACE] "+format, values...)
	}
}

func safeURL(url string) string {
	if i := strings.Index(url, "/dnsleak/test/"); i >= 0 {
		return url[:i] + "/dnsleak/test/[REDACTED]"
	}
	return url
}

func clientForInterface(value string) (*http.Client, error) {
	if value == "" {
		return &http.Client{Timeout: 30 * time.Second}, nil
	}
	ip := net.ParseIP(value)
	if ip == nil {
		device, err := net.InterfaceByName(value)
		if err != nil {
			return nil, err
		}
		addresses, err := device.Addrs()
		if err != nil {
			return nil, err
		}
		for _, address := range addresses {
			candidate, _, _ := net.ParseCIDR(address.String())
			if candidate != nil && !candidate.IsLoopback() {
				ip = candidate
				break
			}
		}
	}
	if ip == nil {
		return nil, fmt.Errorf("cannot determine an address for interface %q", value)
	}
	dialer := &net.Dialer{LocalAddr: &net.TCPAddr{IP: ip}}
	transport := &http.Transport{DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
		return dialer.DialContext(ctx, network, address)
	}}
	return &http.Client{Transport: transport, Timeout: 30 * time.Second}, nil
}

func getContent(url string) ([]byte) {
	started := time.Now()
	logInfo("HTTP GET %s", safeURL(url))
	resp, err := httpClient.Get(url)
	if err != nil {
		raiseError(fmt.Errorf("GET error: %v", err))
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		raiseError(fmt.Errorf("Status error: %v", resp.StatusCode))
	}

	data, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		raiseError(fmt.Errorf("Read body: %v", err))
	}
	logInfo("HTTP request finished; status=%d; bytes=%d; duration=%s", resp.StatusCode, len(data), time.Since(started))
	logTrace("Response headers: %v", resp.Header)

	return data
}

func getId() (string) {
	return string(getContent(fmt.Sprintf("https://%s/id", ApiDomain)))
}

func fakePing(testId string, probes int, parallel int) () {
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, parallel)

	for i := 1; i <= probes; i++ {
		urlPing := fmt.Sprintf("https://%d.%s.%s", i, testId, ApiDomain)
		wg.Add(1)
		semaphore <- struct{}{}
		go func(urlPing string, probe int) {
			defer wg.Done()
			defer func() {
				<-semaphore
			}()
			started := time.Now()
			logInfo("Starting DNS probe %d of %d", probe, probes)
			logTrace("DNS probe URL: %s", urlPing)
			response, err := httpClient.Get(urlPing)
			if response != nil {
				response.Body.Close()
			}
			logInfo("DNS probe %d finished; duration=%s; error=%v", probe, time.Since(started), err)
		}(urlPing, i)
	}
	wg.Wait()
}

func getResult(testId string) ([]Block) {
	// send GET request
	data := getContent(fmt.Sprintf("https://%s/dnsleak/test/%s?json", ApiDomain, testId))

	var xml []Block

	err := json.Unmarshal(data, &xml)
	raiseError(err)

	return xml
}

func printResult(result []Block, Type string) {
	for _, Block := range result {
		if Block.Type != Type {
			continue
		}

		if Block.Asn != "" {
			fmt.Printf("%s [%s, %s]\n", Block.Ip, Block.CountryName, Block.Asn)
			continue
		}

		if Block.CountryName != "" {
			fmt.Printf("%s [%s]\n", Block.Ip, Block.CountryName)
			continue
		}

		if Block.Ip != "" {
			fmt.Printf("%s\n", Block.Ip)
		}
	}
}

func logResult(result []Block) {
	conclusion := ""

	for _, block := range result {
		switch block.Type {
		case "ip":
			logInfo("public_ip=%s; country=%s; asn=%s", block.Ip, block.CountryName, block.Asn)
		case "dns":
			logInfo("dns_server=%s; country=%s; asn=%s", block.Ip, block.CountryName, block.Asn)
		case "conclusion":
			conclusion = block.Ip
			logInfo("conclusion=%s", conclusion)
		}
	}

	normalized := strings.ToLower(conclusion)
	switch {
	case strings.Contains(normalized, "not leaking"), strings.Contains(normalized, "no leak"):
		logInfo("result=no_leak")
	case strings.Contains(normalized, "may be leaking"), strings.Contains(normalized, "leak detected"):
		logInfo("result=leak_detected")
	default:
		logInfo("result=unknown")
	}
}

func main() {
	flags := flag.NewFlagSet(os.Args[0], flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	var networkInterface, logFile string
	var showHelp bool
	var probes int
	var parallel int
	var shortOutput bool
	var watch int

	flags.StringVar(&networkInterface, "i", "", "use a specific network interface")
	flags.StringVar(&networkInterface, "interface", "", "use a specific network interface")
	flags.IntVar(&probes, "p", 30, "number of DNS probes to send")
	flags.IntVar(&probes, "probes", 30, "number of DNS probes to send")
	flags.IntVar(&parallel, "j", 30, "maximum simultaneous probes")
	flags.IntVar(&parallel, "parallel", 30, "maximum simultaneous probes")
	flags.BoolVar(&shortOutput, "s", false, "print a one-line result")
	flags.BoolVar(&shortOutput, "short", false, "print a one-line result")
	flags.IntVar(&watch, "w", 0, "repeat interval in seconds")
	flags.IntVar(&watch, "watch", 0, "repeat interval in seconds")
	flags.StringVar(&verboseLevel, "v", "", "write diagnostics: info or trace")
	flags.StringVar(&verboseLevel, "verbose", "", "write diagnostics: info or trace")
	flags.StringVar(&logFile, "log-file", "", "set the log path")
	flags.BoolVar(&showHelp, "h", false, "show help")
	flags.BoolVar(&showHelp, "help", false, "show help")

	flags.Usage = func() {
		fmt.Fprintf(flags.Output(), "Usage: %s [OPTIONS]\n\nOptions:\n", filepath.Base(os.Args[0]))
		fmt.Fprintln(flags.Output(), "  -i, --interface NAME|IP  Use a specific network interface")
		fmt.Fprintln(flags.Output(), "  -p, --probes NUMBER      Number of DNS probes to send (default: 30)")
		fmt.Fprintln(flags.Output(), "  -j, --parallel NUMBER    Maximum simultaneous probes (default: 30)")
		fmt.Fprintln(flags.Output(), "  -s, --short              Print a one-line result")
		fmt.Fprintln(flags.Output(), "  -w, --watch SECONDS      Repeat in short mode (minimum: 10 seconds)")
		fmt.Fprintln(flags.Output(), "  -v, --verbose LEVEL      Write diagnostics: info or trace")
		fmt.Fprintln(flags.Output(), "      --log-file FILE      Set the log path (implies --verbose info)")
		fmt.Fprintln(flags.Output(), "  -h, --help               Show this help")
	}

	if err := flags.Parse(os.Args[1:]); err != nil {
		os.Exit(2)
	}
	if showHelp {
		flags.Usage()
		return
	}
	if flags.NArg() != 0 {
		fmt.Fprintf(os.Stderr, "Unexpected argument: %s\n", flags.Arg(0))
		os.Exit(2)
	}
	if verboseLevel != "" && verboseLevel != "info" && verboseLevel != "trace" {
		fmt.Fprintf(os.Stderr, "Invalid verbosity level %q; expected info or trace.\n", verboseLevel)
		os.Exit(2)
	}
	if probes < 1 || probes > 100 {
		fmt.Fprintln(os.Stderr, "Invalid probe count; expected an integer from 1 to 100.")
		os.Exit(2)
	}
	if parallel < 1 || parallel > 100 {
		fmt.Fprintln(os.Stderr, "Invalid parallel count; expected an integer from 1 to 100.")
		os.Exit(2)
	}
	if watch != 0 && watch < 10 {
		fmt.Fprintln(os.Stderr, "Invalid watch interval; expected at least 10 seconds.")
		os.Exit(2)
	}
	if watch != 0 {
		shortOutput = true
	}
	if logFile != "" && verboseLevel == "" {
		verboseLevel = "info"
	}
	if verboseLevel != "" {
		if logFile == "" {
			logFile = defaultLogFile()
		}
		raiseError(os.MkdirAll(filepath.Dir(logFile), 0700))
		file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
		raiseError(err)
		raiseError(os.Chmod(logFile, 0600))
		defer file.Close()
		diagnosticLogger = log.New(file, "", log.LstdFlags)
		if os.Getenv("DNSLEAK_WATCH_CHILD") != "1" {
			fmt.Printf("Diagnostic log: %s\n", logFile)
		}
	}

	var err error
	httpClient, err = clientForInterface(networkInterface)
	raiseError(err)
	logInfo("dnsleaktest started; OS=%s; interface=%s; probes=%d; parallel=%d", runtime.GOOS, networkInterface, probes, parallel)
	testStarted := time.Now()

	// get an id fo testing
	testId := getId()

	// ping fake domains
	fakePing(testId, probes, parallel)

	// parse test result
	result := getResult(testId)
	logResult(result)

	// show the testing result
	dns := 0

	for _, Block := range result {
		switch Block.Type {
		case "dns":
			dns++
		}
	}

	if shortOutput {
		conclusion := ""

		for _, block := range result {
			if block.Type == "conclusion" {
				conclusion = strings.ToLower(block.Ip)
			}
		}

		status := "unknown"
		if strings.Contains(conclusion, "not leaking") || strings.Contains(conclusion, "no leak") {
			status = "no_leak"
		} else if strings.Contains(conclusion, "may be leaking") || strings.Contains(conclusion, "leak detected") {
			status = "leak_detected"
		}

		fmt.Printf("%s %.2fs %s\n", time.Now().Format(time.RFC3339), time.Since(testStarted).Seconds(), status)
		logInfo("dnsleaktest finished; dns_servers=%d; exit=0", dns)

		if watch == 0 {
			return
		}

		childArgs := []string{"-p", fmt.Sprint(probes), "-j", fmt.Sprint(parallel), "-s"}

		if networkInterface != "" {
			childArgs = append(childArgs, "-i", networkInterface)
		}
		if verboseLevel != "" {
			childArgs = append(childArgs, "-v", verboseLevel)
		}
		if logFile != "" {
			childArgs = append(childArgs, "--log-file", logFile)
		}

		for {
			time.Sleep(time.Duration(watch) * time.Second)
			command := exec.Command(os.Args[0], childArgs...)
			command.Env = append(os.Environ(), "DNSLEAK_WATCH_CHILD=1")
			command.Stdout = os.Stdout
			command.Stderr = os.Stderr
			_ = command.Run()
		}
	}

	fmt.Print("Your IP:\n")
	printResult(result, "ip")

	if dns == 0 {
		fmt.Print("No DNS servers found\n")
	} else {
		if dns == 1 {
			fmt.Printf("You use %d DNS server:\n", dns)
		} else {
			fmt.Printf("You use %d DNS servers:\n", dns)
		}
		printResult(result, "dns")
	}

	fmt.Print("Conclusion:\n")
	printResult(result, "conclusion")
	logInfo("dnsleaktest finished; dns_servers=%d; exit=0", dns)

}
