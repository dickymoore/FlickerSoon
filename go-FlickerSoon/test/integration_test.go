package main

import (
	"testing"
)

func TestOMDBAPIIntegration(t *testing.T) {
	// Test case: Fetch movie info from OMDB API
	movieTitle := "Inception"
	apiKey := "your-omdb-api-key" // Provide a valid API key for testing

	movieInfo, err := api.GetMovieInfo(movieTitle, apiKey)
	if err != nil {
		t.Errorf("Failed to fetch movie info: %v", err)
	}

	// Assert that movieInfo contains expected fields
	if movieInfo["Title"] != "Inception" {
		t.Errorf("Unexpected movie title: got %s, want %s", movieInfo["Title"], "Inception")
	}
	// Add more assertions as needed
}
