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
	rSubDomainId2 := _random(1, 10)
	initUrl := fmt.Sprintf("https://%d.%d.%s", rSubDomainId2, rSubDomainId1, ApiDomain)
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

func main() {
	//create new request to server to get an id fo testing
	testId := fakePing()
	//test DNS leak
	result := getResult(testId)
	//show the testing result
	for _, Block := range result {
		switch Block.Type {

		case "ip":
			fmt.Printf("Your IP: \n%s [%s, %s]\n", Block.Ip, Block.CountryName, Block.Asn)
		case "dns":
			fmt.Printf("DNS Server: %s [%s, %s]\n", Block.Ip, Block.CountryName, Block.Asn)
		case "conclusion":
			defer fmt.Printf("Conclusion: \n%s\n", Block.Ip)
		}

	}
}
