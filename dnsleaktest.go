package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"
)

var ApiDomain = "bash.ws"

type Block struct {
	Ip          string `json:"ip"`
	Country     string `json:"country"`
	CountryName string `json:"country_name"`
	Asn         string `json:"asn"`
	Type        string `json:"type"`
}

func raiseError(err error) {
	if err == nil {
		return;
	}

	panic(err)
}

func getContent(url string) ([]byte) {
	resp, err := http.Get(url)
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

	return data
}

func getId() (string) {
	return string(getContent(fmt.Sprintf("https://%s/id", ApiDomain)))
}

func fakePing(testId string) () {
	var wg sync.WaitGroup

	for i := 0; i <= 10; i++ {
		urlPing := fmt.Sprintf("https://%d.%s.%s", i, testId, ApiDomain)
		wg.Add(1)
		go func(urlPing string) {
			defer wg.Done()
			http.Get(urlPing)
		}(urlPing)
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

func main() {

	// get an id fo testing
	testId := getId()

	// ping fake domains
	fakePing(testId)

	// parse test result
	result := getResult(testId)

	// show the testing result
	dns := 0
	for _, Block := range result {
		switch Block.Type {

		case "dns":
			dns++
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

}
