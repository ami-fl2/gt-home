package main

import (
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/golang/glog"
	"github.com/jessevdk/go-flags"
)

// protect against out of memory kills
const nLimit = 10000

var format string

// Fibonacci returns the first `n` Fibonacci numbers
func Fibonacci(n int) []big.Int {
	if n <= 0 {
		glog.Warning("Call Fibonacci with a positive integer")
		return []big.Int{}
	}

	// Using BigInt here since int is 64 bits and Fibonacci numbers grow quickly,
	// so if it's over a 100, it will wrap negative numbers
	// pre-allocating a new slice instead of appending since its allocating memory all at once
	fib := make([]big.Int, n)

	fib[0].SetInt64(0)
	if n > 1 {
		fib[1].SetInt64(1)
	}

	// fill in the rest of the Fibonacci numbers
	// starting the loop at 2 since the first 2 numbers are always 0 and 1
	for i := 2; i < n; i++ {
		// each number is the sum of the previous two in the array
		// calculate the next two numbers and store them in the array
		// perform the addition in place directly into the slice
		// using pointers here to avoid allocating new memory for each addition (also the Add expected pointers)
		fib[i].Add(&fib[i-1], &fib[i-2])
	}

	return fib
}

// getFibs is the response handler for the web server
func getFibs(w http.ResponseWriter, r *http.Request) {
	// ignore any request not in the root path
	if r.URL.Path != "/" {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	param, ok := r.URL.Query()["n"]
	if !ok || len(param) == 0 || len(param[0]) < 1 {
		glog.Warning("Url was called without n parameter")
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, err := w.Write([]byte("Error: n url parameter is missing, pass it with ?n=<positive integer>"))
		if err != nil {
			glog.Errorf("Error writing to response writer: %v", err)
			return
		}
		return
	}

	n, err := strconv.Atoi(param[0])
	if err != nil || n < 0 || n > nLimit {
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, err = w.Write([]byte("Error: n must be a positive integer between 0 and " + strconv.Itoa(nLimit)))
		if err != nil {
			glog.Errorf("Error writing to response writer: %v", err)
		}
		return
	}

	nums := Fibonacci(n)

	if format == "json" {
		printFibsToJson(w, nums)
	} else {
		printFibsPlaintext(w, nums)
	}
}

func printFibsPlaintext(w http.ResponseWriter, nums []big.Int) {
	w.Header().Set("Content-Type", "text/plain")
	strNums := make([]string, len(nums))

	for i := range nums {
		strNums[i] = nums[i].String()
	}

	_, err := w.Write([]byte(strings.Join(strNums, ", ")))
	if err != nil {
		glog.Errorf("Error writing to response writer: %v", err)
	}
}

func printFibsToJson(w http.ResponseWriter, nums []big.Int) {
	w.Header().Set("Content-Type", "application/json")
	jsonNums := make([]string, len(nums))

	for i := range nums {
		jsonNums[i] = nums[i].String()
	}

	err := json.NewEncoder(w).Encode(jsonNums)
	if err != nil {
		glog.Errorf("Error writing JSON to response writer: %v", err)
	}
}

// LoggingMiddleware gets the handler func and wraps it with logging for method, path, and time taken for each request
func LoggingMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		glog.Infof("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	}
}

// RecoveryMiddleware prevents the server from crashing if there is a panic
func RecoveryMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				glog.Errorf("Recovered from panic: %v", err)
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	}
}

func main() {
	var opts struct {
		Port   string `short:"p" long:"port" env:"PORT" default:"8000" description:"Port to run the Fibonacci server on"`
		Output string `short:"o" long:"output" env:"OUTPUT" default:"plaintext" description:"Output format plaintext or json defaults to plaintext"`
	}
	_, err := flags.Parse(&opts)
	if err != nil {
		glog.Fatalf("Error parsing flags: %v", err)
	}
	format = opts.Output

	fmt.Println("Fibonacci server started")
	fmt.Printf("Visit http://localhost:%s?n=10 to get the first 10 (or any other number in place of 10) Fibonacci numbers\n", opts.Port)
	handler := LoggingMiddleware(RecoveryMiddleware(getFibs))
	http.HandleFunc("/", handler)

	// add health checks endpoint
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, err = w.Write([]byte("ok"))
		if err != nil {
			return
		}
	})
	err = http.ListenAndServe(fmt.Sprintf(":%s", opts.Port), nil)
	if err != nil {
		glog.Fatalf("Error starting server: %v", err)
	}
}
