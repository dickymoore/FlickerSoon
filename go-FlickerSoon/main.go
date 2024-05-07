package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
)

var config *Config

type Config struct {
	Apis struct {
		OmdbApiKey string
	}
	Endpoints struct {
		OmdbEndpoint string
	}
}

func LoadConfig() (*Config, error) {
	configPath := "./config.toml"
	file, err := os.Open(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open config file: %w", err)
	} else {
		println("Config loaded.")
	}
	contents, err := io.ReadAll(file)
	defer file.Close()
	if err != nil {
		log.Fatalf("failed to read config file: %v", err)
	} else {
		numLines := strings.Count(string(contents), "\n")
		fmt.Printf("Read %d lines of config.\n", numLines)
	}

	var config Config
	if _, err := toml.Decode(string(contents), &config); err != nil {
		return nil, fmt.Errorf("failed to decode config file: %w", err)
	}
	fmt.Println("Config loaded successfully:", config)
	fmt.Println("OMDB API Key:", config.Apis.OmdbApiKey)
	return &config, nil
}

func buildAPIURL(title, year, baseURL, typeParam string) string {
	// Construct the base URL
	apiURL := fmt.Sprintf(baseURL)

	// Add title parameter
	apiURL += "t=" + url.QueryEscape(title)

	// Add year parameter if provided
	if year != "" {
		apiURL += "&y=" + year
	}

	// Add type parameter if provided
	if typeParam != "" {
		apiURL += "&type=" + typeParam
	}

	return apiURL
}
func fetchData(title, year, baseURL, apiKey, typeParam string) (map[string]interface{}, error) {
	apiURL := buildAPIURL(title, year, baseURL+apiKey+"&", typeParam)

	// Make an HTTP request using the client
	resp, err := http.Get(apiURL)
	if err != nil {
		return nil, fmt.Errorf("failed to make HTTP request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Unmarshal JSON response
	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %w", err)
	}

	return data, nil
}
func main() {
	var err error
	config, err = LoadConfig()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	client := http.Client{
		Timeout: 10 * time.Second,
	}

	// Set the endpoint using the variable in the config file
	apiUrl := buildAPIURL("Civil War", "2024", config.Endpoints.OmdbEndpoint+config.Apis.OmdbApiKey+"&", "movie")

	// Make an HTTP request using the client
	resp, err := client.Get(apiUrl)
	if err != nil {
		log.Fatalf("failed to make HTTP request: %v", err)
	}

	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Fatalf("failed to read response body: %v", err)
	}

	// Print the response body
	fmt.Println("Response Body:", string(body))

	// Process the data (for example, unmarshal JSON)
	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		log.Fatalf("failed to unmarshal JSON: %v", err)
	}

	// Print some information from the data
	fmt.Println("Title:", data["Title"])
	fmt.Println("Year:", data["Year"])
}
