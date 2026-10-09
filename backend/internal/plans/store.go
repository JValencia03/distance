package plans

import (
	"slices"
	"sync"
)

// MemoryStore keeps plans in memory. Data is lost on restart; it is the
// storage for the first MVP iteration until persistence is needed.
type MemoryStore struct {
	mu    sync.RWMutex
	plans map[string]Plan
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{plans: map[string]Plan{}}
}

func (s *MemoryStore) add(p Plan) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.plans[p.ID] = clonePlan(p)
}

func (s *MemoryStore) get(id string) (Plan, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.plans[id]
	return clonePlan(p), ok
}

func (s *MemoryStore) all() []Plan {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]Plan, 0, len(s.plans))
	for _, p := range s.plans {
		result = append(result, clonePlan(p))
	}
	return result
}

// clonePlan copies the participants slice so callers cannot mutate stored
// state outside the lock.
func clonePlan(p Plan) Plan {
	p.Participants = slices.Clone(p.Participants)
	return p
}
