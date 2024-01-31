go mod download && go mod verify
CGO_ENABLED=0 go build -o backend cmd/main.go