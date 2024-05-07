package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHTTPHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/movies?title=Inception", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(apiHandler)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expected := `{"Title":"Inception","Year":"2010","Plot":"A thief who steals corporate secrets through the use of dream-sharing technology"`
	if rr.Body.String() != expected {
		t.Errorf("Handler returned unexpected body: got %v want %v",
			rr.Body.String(), expected)
	}
}
