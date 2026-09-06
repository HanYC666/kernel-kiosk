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
		if len(store.entries) > store.maxSize {
			store.entries = store.entries[:store.maxSize]
			if err := store.persist(); err != nil {
				return nil, err
			}
		}
	}
	return store, nil
}

func (s *Store) List() []Entry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return append([]Entry(nil), s.entries...)
}

func (s *Store) Add(name string, score int) (Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := Entry{Name: name, Score: score, Submitted: time.Now().UTC()}
	s.entries = append(s.entries, entry)
	s.sort()
	if len(s.entries) > s.maxSize {
		s.entries = s.entries[:s.maxSize]
	}
	if err := s.persist(); err != nil {
		return Entry{}, err
	}
	return entry, nil
}

func (s *Store) sort() {
	sort.SliceStable(s.entries, func(i, j int) bool {
		if s.entries[i].Score == s.entries[j].Score {
			return s.entries[i].Submitted.Before(s.entries[j].Submitted)
		}
		return s.entries[i].Score > s.entries[j].Score
	})
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
