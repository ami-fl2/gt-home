# Build the Go container
FROM golang:1.25-alpine AS base
WORKDIR /app
COPY . .
RUN cd go && go mod download && go build -o fibs .

FROM alpine:latest
COPY --from=base /app/go/fibs /bin/fibs
CMD ["/bin/fibs"]