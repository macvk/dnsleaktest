package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"time"
)

var ApiDomain = "bash.ws"

type Block struct {
	Ip          string `json:"ip"`
	Country     string `json:"country"`
	CountryName string `json:"country_name"`
	Asn         string `json:"asn"`
	Type        string `json:"type"`
}

func _pError(err error) {
	if err != nil {
		panic(err)
	}
}

func _random(min, max int) int {
	rand.Seed(time.Now().Unix())
	return rand.Intn(max-min) + min
}

func fakePing() int {

	rSubDomainId1 := _random(1000000, 9999999)

	initUrl := fmt.Sprintf("https://%d.%d.%s", 0, rSubDomainId1, ApiDomain)
	for i := 1; i <= 10; i++ {
		rSubDomainId2 := i
		initUrl = fmt.Sprintf("https://%d.%d.%s", rSubDomainId2, rSubDomainId1, ApiDomain)
		go http.Get(initUrl)
	}
	fmt.Println("initUrl: ", initUrl)
	http.Get(initUrl)
	return rSubDomainId1

}

func getResult(id int) []Block {

	getUrl := fmt.Sprintf("https://%s/dnsleak/test/%d?json", ApiDomain, id)
	// send GET request
	res, err := http.Get(getUrl)
	_pError(err)
	defer res.Body.Close()

	var data []Block

	if res.StatusCode == http.StatusOK {

		bodyBytes, _ := ioutil.ReadAll(res.Body)
		err = json.Unmarshal(bodyBytes, &data)

		if err != nil {
			fmt.Println(err)
		}

	}

	return data
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
	//create new request to server to get an id fo testing
	testId := fakePing()
	//test DNS leak
	result := getResult(testId)
	//show the testing result

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
