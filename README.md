# Fibonacci Service (Platform Engineering Project)

A production-ready web service written in Go that generates Fibonacci sequences. This project demonstrates high-performance arithmetic, observability, and robust error handling designed for cloud-native environments.

## Features

* **Arbitrary Precision:** Uses `math/big` to calculate Fibonacci numbers beyond the 64-bit integer limit ($n > 92$).
* **Resource Safety:** Implemented a hard limit (`n=10000`) and efficient memory reuse to prevent Denial of Service (DoS) through memory exhaustion.
* **Observability:** Includes structured logging middleware and a `/healthz` endpoint for Kubernetes liveness/readiness probes.
* **Resilience:** Built-in Recovery middleware to catch and log panics, ensuring the service remains available.
* **Configurability:** CLI flags for port selection and output formatting (Plaintext vs. JSON).

## Design Philosophy

### Why `math/big`?
Standard 64-bit integers overflow at the 93rd Fibonacci number. To ensure "production-grade" correctness, this service uses arbitrary-precision arithmetic. This allows the service to return accurate results for large requests without silent integer wrapping.

### Memory Management
The Fibonacci logic is implemented to perform additions directly within the pre-allocated slice memory:
`fib[i].Add(&fib[i-1], &fib[i-2])`

This approach minimizes heap allocations and reduces Garbage Collector (GC) pressure by reusing the `big.Int` structs already present in the slice rather than creating new objects in every loop iteration.

[Image of Go slice memory allocation for big.Int structs]

## Getting Started

### Prerequisites
* Go 1.21+
* Git

### Installation & Running
1.  **Clone the repository**
2.  **Download dependencies:**
    ```bash
    go mod tidy
    ```
3.  **Run the server:**
    ```bash
    go run main.go --port 8000 --output json
    ```

### Build Docker
```bash
docker build -t fibonacci-service .
```

### Run Docker
by default, output is plaintext, and port is 8000 you can override port using PORT env variable or the OUTPUT=json if you want json output
```bash
docker run -p 8000:8000 -e PORT=8080 fibonacci-service
```

### Usage
Request the first 10 Fibonacci numbers:
```bash
curl "http://localhost:8000/?n=10"


### Release via Github Actions
To release a new version of the service, run the workflow manually from the Actions tab and specify the new version number (semver)

### Local cluster with Kind (Makefile)

use the provided Makefile to create a local Kubernetes cluster with Kind and deploy the Fibonacci service.

the following command will create the cluster, deploy the service and test the service
```bash
make integration 
```

or run separate commands
```bash
make kind-create          
make helm-install 
```