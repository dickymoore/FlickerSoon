package api

import (
	"testing"
)

func TestGetMovieInfo(t *testing.T) {
	// Test case: Fetch movie info by title
	movieTitle := "Inception"
	apiKey := "your-omdb-api-key" // Provide a valid API key for testing
	movieInfo, err := GetMovieInfo(movieTitle, apiKey)
	if err != nil {
		t.Errorf("GetMovieInfo failed: %v", err)
	}

	// Assert that movieInfo contains expected fields
	if movieInfo["Title"] != "Inception" {
		t.Errorf("Unexpected movie title: got %s, want %s", movieInfo["Title"], "Inception")
	}
	// Add more assertions as needed
}
