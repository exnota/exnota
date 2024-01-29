# Including two linters for now to get a feel for which is more useful. Only
# golangci-lint has VS Code integration, but staticcheck seems more popular.

staticcheck .
# config in .golangci.yml
golangci-lint run