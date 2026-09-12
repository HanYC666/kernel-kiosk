package scores

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

type Entry struct {
	Name      string    `json:"name"`
	Score     int       `json:"score"`
	Game      string    `json:"game,omitempty"`
	Submitted time.Time `json:"submitted"`
}

type Store struct {
	mu      sync.RWMutex
	path    string
	maxSize int
	entries []Entry
}

func Open(path string, maxSize int) (*Store, error) {
	store := &Store{path: path, maxSize: maxSize}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return store, nil
	}
	if err != nil {
		return nil, err
	}
	if len(data) > 0 {
		if err := json.Unmarshal(data, &store.entries); err != nil {
			return nil, err
		}
		store.sort()
		before := len(store.entries)
		store.trim("platform")
		store.trim("typing")
		if len(store.entries) != before {
			if err := store.persist(); err != nil {
				return nil, err
			}
		}
	}
	return store, nil
}

func (s *Store) List(game string) []Entry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entries := make([]Entry, 0, len(s.entries))
	for _, entry := range s.entries {
		if entry.Game == game || (game == "platform" && entry.Game == "") {
			entries = append(entries, entry)
		}
	}
	return entries
}

func (s *Store) Add(name string, score int, game string) (Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := Entry{Name: name, Score: score, Game: game, Submitted: time.Now().UTC()}
	s.entries = append(s.entries, entry)
	s.trim(game)
	if err := s.persist(); err != nil {
		return Entry{}, err
	}
	return entry, nil
}

func (s *Store) trim(game string) {
	gameEntries := make([]Entry, 0, len(s.entries))
	otherEntries := make([]Entry, 0, len(s.entries))
	for _, entry := range s.entries {
		if entry.Game == game || (game == "platform" && entry.Game == "") {
			gameEntries = append(gameEntries, entry)
		} else {
			otherEntries = append(otherEntries, entry)
		}
	}
	sort.SliceStable(gameEntries, func(i, j int) bool { return scoreBefore(gameEntries[i], gameEntries[j]) })
	if len(gameEntries) > s.maxSize {
		gameEntries = gameEntries[:s.maxSize]
	}
	s.entries = append(otherEntries, gameEntries...)
	s.sort()
}

func (s *Store) sort() {
	sort.SliceStable(s.entries, func(i, j int) bool { return scoreBefore(s.entries[i], s.entries[j]) })
}

func scoreBefore(i, j Entry) bool {
	if i.Score == j.Score {
		return i.Submitted.Before(j.Submitted)
	}
	return i.Score > j.Score
}

func (s *Store) persist() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0750); err != nil {
		return err
	}
	data, err := json.Marshal(s.entries)
	if err != nil {
		return err
	}
	temp, err := os.CreateTemp(filepath.Dir(s.path), ".scores-*")
	if err != nil {
		return err
	}
	tempName := temp.Name()
	defer os.Remove(tempName)
	if _, err = temp.Write(data); err != nil {
		temp.Close()
		return err
	}
	if err = temp.Chmod(0600); err != nil {
		temp.Close()
		return err
	}
	if err = temp.Close(); err != nil {
		return err
	}
	return os.Rename(tempName, s.path)
}
