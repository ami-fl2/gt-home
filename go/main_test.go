package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFibonacci(t *testing.T) {
	tests := []struct {
		n        int
		expected []string
	}{
		{0, []string{}},
		{1, []string{"0"}},
		{2, []string{"0", "1"}},
		{5, []string{"0", "1", "1", "2", "3"}},
	}

	for _, tt := range tests {
		result := Fibonacci(tt.n)
		if len(result) != len(tt.expected) {
			t.Errorf("Fibonacci(%d) length = %d; want %d", tt.n, len(result), len(tt.expected))
		}

		for i, val := range result {
			if val.String() != tt.expected[i] {
				t.Errorf("Fibonacci(%d)[%d] = %s; want %s", tt.n, i, val.String(), tt.expected[i])
			}
		}
	}
}

func TestGetFibsHandler(t *testing.T) {
	// Test a valid request
	req, err := http.NewRequest("GET", "/?n=5", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getFibs)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	expected := "0, 1, 1, 2, 3"
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
	}
}

func TestGetFibsInvalidInput(t *testing.T) {
	req, err := http.NewRequest("GET", "/?n=abc", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getFibs)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusUnprocessableEntity {
		t.Errorf("handler returned wrong status code for invalid input: got %v want %v", status, http.StatusUnprocessableEntity)
	}
}

func TestGetFibsMissingParameter(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getFibs)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusUnprocessableEntity {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusUnprocessableEntity)
	}
}

func TestGetFibsOutOfBounds(t *testing.T) {
	req, err := http.NewRequest("GET", "/?n=99999", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getFibs)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusUnprocessableEntity {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusUnprocessableEntity)
	}
}

func TestGetFibsNotFound(t *testing.T) {
	req, err := http.NewRequest("GET", "/invalid?n=5", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(getFibs)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusNotFound {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusNotFound)
	}
}
