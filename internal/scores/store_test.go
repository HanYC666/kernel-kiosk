package scores

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestOpenTrimsExistingScoresToMaximum(t *testing.T) {
	path := filepath.Join(t.TempDir(), "scores.json")
	entries := make([]Entry, 51)
	for index := range entries {
		entries[index] = Entry{
			Name:      "player",
			Score:     51 - index,
			Submitted: time.Date(2026, time.January, 1, 0, 0, index, 0, time.UTC),
		}
	}
	data, err := json.Marshal(entries)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}

	store, err := Open(path, 50)
	if err != nil {
		t.Fatal(err)
	}
	if got := len(store.List()); got != 50 {
		t.Fatalf("stored entries = %d, want 50", got)
	}

	persisted, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var saved []Entry
	if err := json.Unmarshal(persisted, &saved); err != nil {
		t.Fatal(err)
	}
	if got := len(saved); got != 50 {
		t.Fatalf("persisted entries = %d, want 50", got)
	}
}
