APP := kernel-kiosk
WEB_DIR := web

.PHONY: run test build export-web build-all

run:
	go run ./cmd/$(APP)

test:
	go test ./...

build:
	go build -trimpath -ldflags="-s -w" -o bin/$(APP) ./cmd/$(APP)

export-web:
	@test -n "$(GODOT)" || (echo "Set GODOT to a Godot 4 executable, e.g. GODOT=godot"; exit 1)
	$(GODOT) --headless --path . --export-release "Web" $(WEB_DIR)/index.html
	cp rankings.html $(WEB_DIR)/rankings.html

build-all:
	mkdir -p bin
	GOOS=linux GOARCH=arm GOARM=6 go build -trimpath -ldflags="-s -w" -o bin/$(APP)-linux-armv6 ./cmd/$(APP)
	GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o bin/$(APP)-linux-arm64 ./cmd/$(APP)
	GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o bin/$(APP)-linux-amd64 ./cmd/$(APP)
	GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o bin/$(APP)-darwin-arm64 ./cmd/$(APP)
	GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o bin/$(APP)-darwin-amd64 ./cmd/$(APP)
