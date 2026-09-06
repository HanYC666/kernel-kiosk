package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"kernel-kiosk/internal/scores"
)

const (
	minScore        = -999
	maxScore        = 999
	maxName         = 24
	maxPublicScores = 50
)

func main() {
	addr := flag.String("addr", "127.0.0.1:8009", "listen address")
	webRoot := flag.String("web-root", "web", "Godot web export directory")
	dataFile := flag.String("scores", "data/scores.json", "persistent score file")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	store, err := scores.Open(*dataFile, maxPublicScores)
	if err != nil {
		logger.Error("open score store", "error", err)
		os.Exit(1)
	}

	h := newHandler(*webRoot, store, logger)
	server := &http.Server{
		Addr:              *addr,
		Handler:           h,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		// The Godot WebAssembly bundle is roughly 40 MB and can take longer than
		// 20 seconds to stream from low-power hardware through a reverse proxy.
		WriteTimeout:   5 * time.Minute,
		IdleTimeout:    60 * time.Second,
		MaxHeaderBytes: 8 << 10,
	}

	go func() {
		logger.Info("kernel kiosk listening", "addr", *addr, "web_root", *webRoot)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
	}
}

func newHandler(webRoot string, store *scores.Store, logger *slog.Logger) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	mux.HandleFunc("GET /api/scores", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, store.List())
	})
	mux.HandleFunc("GET /api/scores/submit", func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimSpace(r.URL.Query().Get("name"))
		if len([]rune(name)) == 0 || len([]rune(name)) > maxName {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name must contain 1-24 characters"})
			return
		}
		for _, char := range name {
			if !(char == ' ' || char == '-' || char == '_' || char >= '0' && char <= '9' || char >= 'A' && char <= 'Z' || char >= 'a' && char <= 'z') {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name contains unsupported characters"})
				return
			}
		}
		var score int
		if _, err := fmt.Sscan(r.URL.Query().Get("score"), &score); err != nil || score < minScore || score > maxScore {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "score must be between -999 and 999"})
			return
		}
		entry, err := store.Add(name, score)
		if err != nil {
			logger.Error("save score", "error", err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not save score"})
			return
		}
		writeJSON(w, http.StatusCreated, entry)
	})
	mux.HandleFunc("GET /scores", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/rankings.html", http.StatusFound)
	})

	static := http.FileServer(http.Dir(webRoot))
	mux.Handle("GET /", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			indexPath := filepath.Join(webRoot, "index.html")
			if _, err := os.Stat(indexPath); errors.Is(err, fs.ErrNotExist) {
				http.Error(w, "Godot web export is missing. Run: make export-web", http.StatusServiceUnavailable)
				return
			}
		}
		static.ServeHTTP(w, r)
	}))
	return withSecurityHeaders(withRequestLog(mux, logger))
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func withSecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Resource-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
		// Godot's generated Web shell uses an inline bootstrap to start index.js.
		w.Header().Set("Content-Security-Policy", "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
		next.ServeHTTP(w, r)
	})
}

func withRequestLog(next http.Handler, logger *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Info("request", "method", r.Method, "path", r.URL.Path, "remote", remoteIP(r.RemoteAddr), "duration_ms", time.Since(start).Milliseconds())
	})
}

func remoteIP(addr string) string {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return addr
	}
	return host
}

func scoreboardPage(entries []scores.Entry) string {
	var rows strings.Builder
	for index, entry := range entries {
		fmt.Fprintf(&rows, "<tr><td>%d</td><td>%s</td><td>%d</td></tr>", index+1, entry.Name, entry.Score)
	}
	if len(entries) == 0 {
		rows.WriteString("<tr><td colspan=\"3\">No published scores yet.</td></tr>")
	}
	return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Kernel Kiosk Scores</title><style>body{margin:0;background:#030805;color:#d8ffe5;font:16px monospace;padding:3rem}main{max-width:680px;margin:auto;border:1px solid #46ff9a;padding:2rem}h1{color:#76ffad}table{width:100%;border-collapse:collapse}td{padding:.7rem;border-bottom:1px solid #1f9d5b}</style></head><body><main><h1>KERNEL KIOSK // PUBLIC SCORES</h1><table><thead><tr><td>#</td><td>HANDLE</td><td>SCORE</td></tr></thead><tbody>" + rows.String() + "</tbody></table></main></body></html>"
}
