package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

var config *Config

type Config struct {
	OmdbApiKey   string `toml:"OmdbApiKey"`
	TmdbApiKey   string `toml:"TmdbApiKey"`
	OmdbEndpoint string // Add this field for the endpoint
}

func LoadConfig() (*Config, error) {
	omdbApiKey := os.Getenv("OMDB_API_KEY")
	tmdbApiKey := os.Getenv("TMDB_API_KEY")

	if omdbApiKey == "" || tmdbApiKey == "" {
		return nil, fmt.Errorf("missing API key: OMDB_API_KEY or TMDB_API_KEY")
	}

	// Set the endpoint
	endpoint := "http://www.omdbapi.com/?apikey="
	return &Config{
		OmdbApiKey:   omdbApiKey,
		TmdbApiKey:   tmdbApiKey,
		OmdbEndpoint: endpoint,
	}, nil
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

	// Example usage of config and client
	fmt.Println("OMDB API Key:", config.OmdbApiKey)
	fmt.Println("TMDB API Key:", config.TmdbApiKey)

	// Make an HTTP request using the client
	resp, err := client.Get(config.OmdbEndpoint)
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
