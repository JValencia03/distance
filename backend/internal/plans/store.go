package plans

import (
	"context"
	"slices"
	"sync"
	"time"
)

// Store persists plans and their participants. MemoryStore keeps handler
// tests fast and dependency-free; PostgresStore is the durable storage.
type Store interface {
	Create(ctx context.Context, p Plan) error
	// Get returns errNotFound when the plan does not exist.
	Get(ctx context.Context, id string) (Plan, error)
	// Current returns at least every active plan that has not ended at now,
	// whether it is upcoming or ongoing; callers apply the discovery filters
	// and ordering.
	Current(ctx context.Context, now time.Time) ([]Plan, error)
	// Join adds the participant to the plan if Plan.canJoin allows it,
	// atomically with respect to other joins, and returns the updated plan.
	Join(ctx context.Context, id string, participant Participant, now time.Time) (Plan, error)
}

// MemoryStore keeps plans in memory. Data is lost on restart.
type MemoryStore struct {
	mu    sync.RWMutex
	plans map[string]Plan
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{plans: map[string]Plan{}}
}

func (s *MemoryStore) Create(_ context.Context, p Plan) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.plans[p.ID] = clonePlan(p)
	return nil
}

func (s *MemoryStore) Get(_ context.Context, id string) (Plan, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.plans[id]
	if !ok {
		return Plan{}, errNotFound
	}
	return clonePlan(p), nil
}

func (s *MemoryStore) Current(_ context.Context, _ time.Time) ([]Plan, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]Plan, 0, len(s.plans))
	for _, p := range s.plans {
		result = append(result, clonePlan(p))
	}
	return result, nil
}

// Join checks and updates the plan under the same write lock, so concurrent
// joins cannot both see a free spot and exceed the limit.
func (s *MemoryStore) Join(_ context.Context, id string, participant Participant, now time.Time) (Plan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.plans[id]
	if !ok {
		return Plan{}, errNotFound
	}
	if err := p.canJoin(participant.UserID, now); err != nil {
		return Plan{}, err
	}
	p.Participants = append(slices.Clone(p.Participants), participant)
	s.plans[id] = p
	return clonePlan(p), nil
}

// clonePlan copies the participants slice so callers cannot mutate stored
// state outside the lock.
func clonePlan(p Plan) Plan {
	p.Participants = slices.Clone(p.Participants)
	return p
}
