package main

import (
	"testing"
)

func BenchmarkGetMovieInfo(b *testing.B) {
	apiKey := "your-omdb-api-key" // Provide a valid API key for testing
	for i := 0; i < b.N; i++ {
		_, err := api.GetMovieInfo("Inception", apiKey)
		if err != nil {
			b.Errorf("Benchmark failed: %v", err)
		}
	}
}
