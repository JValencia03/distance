package plans

import (
	"errors"
	"fmt"
	"os"
	"slices"
	"sync"
	"testing"
	"time"

	"distance/internal/database"
)

// testStore checks the behavior every Store implementation must provide.
// newStore must return an empty store.
func testStore(t *testing.T, newStore func(t *testing.T) Store) {
	t.Run("create and get", func(t *testing.T) {
		store := newStore(t)
		suba, _ := findZone("suba")
		seedPlan(t, store, "p", func(p *Plan) {
			p.Description = "Trae un libro"
			p.MaxParticipants = 4
			p.Duration = 90 * time.Minute
			p.Participants = []Participant{{UserID: "creator", Zone: suba}}
		})

		got, err := store.Get(t.Context(), "p")
		if err != nil {
			t.Fatal(err)
		}
		if got.Title != "Leer" || got.Description != "Trae un libro" || got.MaxParticipants != 4 ||
			got.Activity.Name.es != "Leer" || got.Zone.Name != "Chapinero" || got.Status != StatusActive ||
			!got.StartsAt.Equal(testNow.Add(time.Hour)) || got.Duration != 90*time.Minute ||
			!slices.Equal(got.Participants, []Participant{{UserID: "creator", Zone: suba}}) {
			t.Errorf("round trip mismatch: %+v", got)
		}

		if _, err := store.Get(t.Context(), "missing"); !errors.Is(err, errNotFound) {
			t.Errorf("missing plan error = %v, want errNotFound", err)
		}
	})

	t.Run("current includes upcoming and ongoing plans", func(t *testing.T) {
		store := newStore(t)
		seedPlan(t, store, "future", nil)
		seedPlan(t, store, "ongoing", func(p *Plan) { p.StartsAt = testNow.Add(-30 * time.Minute) })
		seedPlan(t, store, "ended", func(p *Plan) { p.StartsAt = testNow.Add(-time.Hour) })
		seedPlan(t, store, "long-ended", func(p *Plan) {
			p.StartsAt = testNow.Add(-24 * time.Hour)
			p.Duration = maxDuration
		})

		got, err := store.Current(t.Context(), testNow)
		if err != nil {
			t.Fatal(err)
		}
		// Stores may return more; only these two must be there.
		var ids []string
		for _, p := range got {
			ids = append(ids, p.ID)
		}
		if !slices.Contains(ids, "future") || !slices.Contains(ids, "ongoing") {
			t.Errorf("current = %v, want future and ongoing", ids)
		}
	})

	t.Run("join applies the rules", func(t *testing.T) {
		store := newStore(t)
		seedPlan(t, store, "open", func(p *Plan) { p.MaxParticipants = 2 })
		seedPlan(t, store, "cancelled", func(p *Plan) { p.Status = StatusCancelled })
		seedPlan(t, store, "ongoing", func(p *Plan) { p.StartsAt = testNow })
		seedPlan(t, store, "ended", func(p *Plan) { p.StartsAt = testNow.Add(-time.Hour) })
		suba, _ := findZone("suba")
		join := func(planID, userID string) (Plan, error) {
			return store.Join(t.Context(), planID, Participant{UserID: userID, Zone: suba}, testNow)
		}

		p, err := join("open", "ana")
		if err != nil || !slices.Equal(participantIDs(p), []string{"creator", "ana"}) || p.Participants[1].Zone != suba {
			t.Fatalf("join = %+v, %v", p, err)
		}
		if _, err := join("ongoing", "ana"); err != nil {
			t.Errorf("join ongoing plan: %v", err)
		}

		tests := []struct {
			planID, userID string
			want           error
		}{
			{"missing", "ana", errNotFound},
			{"open", "ana", errAlreadyJoined},
			{"open", "bruno", errPlanFull},
			{"cancelled", "ana", errPlanCancelled},
			{"ended", "ana", errPlanEnded},
		}
		for _, tt := range tests {
			if _, err := join(tt.planID, tt.userID); !errors.Is(err, tt.want) {
				t.Errorf("join %s as %s: err = %v, want %v", tt.planID, tt.userID, err, tt.want)
			}
		}

		got, _ := store.Get(t.Context(), "open")
		if !slices.Equal(got.Participants, []Participant{{UserID: "creator", Zone: got.Zone}, {UserID: "ana", Zone: suba}}) {
			t.Errorf("stored participants = %v", got.Participants)
		}
	})

	t.Run("concurrent joins respect the limit", func(t *testing.T) {
		store := newStore(t)
		const limit, requests = 5, 40
		seedPlan(t, store, "p", func(p *Plan) { p.MaxParticipants = limit })

		errs := make([]error, requests)
		var wg sync.WaitGroup
		for i := range requests {
			wg.Go(func() {
				_, errs[i] = store.Join(t.Context(), "p", people(fmt.Sprintf("user-%d", i))[0], testNow)
			})
		}
		wg.Wait()

		joined := 0
		for _, err := range errs {
			switch {
			case err == nil:
				joined++
			case !errors.Is(err, errPlanFull):
				t.Errorf("unexpected error: %v", err)
			}
		}
		got, _ := store.Get(t.Context(), "p")
		if joined != limit-1 || len(got.Participants) != limit {
			t.Errorf("joined = %d, participants = %d; want %d and %d", joined, len(got.Participants), limit-1, limit)
		}
	})
}

func TestMemoryStore(t *testing.T) {
	testStore(t, func(*testing.T) Store { return NewMemoryStore() })
}

// TestPostgresStore runs against a real database. It deletes all plans, so
// point DISTANCE_TEST_DATABASE_URL at a disposable database.
func TestPostgresStore(t *testing.T) {
	url := os.Getenv("DISTANCE_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("DISTANCE_TEST_DATABASE_URL not set")
	}
	pool, err := database.Open(t.Context(), url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := database.Migrate(t.Context(), pool); err != nil {
		t.Fatal(err)
	}

	newStore := func(t *testing.T) Store {
		if _, err := pool.Exec(t.Context(), "TRUNCATE plans CASCADE"); err != nil {
			t.Fatal(err)
		}
		return NewPostgresStore(pool)
	}
	testStore(t, newStore)

	// Deterministic version of the race the concurrent test samples: a join
	// that waits for the lock must see the participant added by the
	// transaction it waited for.
	t.Run("join waiting for the lock sees the previous join", func(t *testing.T) {
		store := newStore(t)
		seedPlan(t, store, "p", func(p *Plan) { p.MaxParticipants = 2 })

		// Another join takes the last spot and holds the lock.
		tx, err := pool.Begin(t.Context())
		if err != nil {
			t.Fatal(err)
		}
		defer tx.Rollback(t.Context())
		if _, err := tx.Exec(t.Context(), "SELECT id FROM plans WHERE id = 'p' FOR UPDATE"); err != nil {
			t.Fatal(err)
		}
		if _, err := tx.Exec(t.Context(), "INSERT INTO plan_participants (plan_id, user_id, zone_id) VALUES ('p', 'ana', 'suba')"); err != nil {
			t.Fatal(err)
		}

		result := make(chan error, 1)
		go func() {
			_, err := store.Join(t.Context(), "p", people("bruno")[0], testNow)
			result <- err
		}()

		// Wait until the join is blocked on the row lock, then release it.
		deadline := time.Now().Add(5 * time.Second)
		for {
			var waiting int
			err := pool.QueryRow(t.Context(),
				"SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock' AND datname = current_database()").Scan(&waiting)
			if err != nil {
				t.Fatal(err)
			}
			if waiting > 0 {
				break
			}
			if time.Now().After(deadline) {
				t.Fatal("join never waited for the lock")
			}
			time.Sleep(10 * time.Millisecond)
		}
		if err := tx.Commit(t.Context()); err != nil {
			t.Fatal(err)
		}

		if err := <-result; !errors.Is(err, errPlanFull) {
			t.Errorf("join after the plan filled up: err = %v, want errPlanFull", err)
		}
		if got, _ := store.Get(t.Context(), "p"); len(got.Participants) != 2 {
			t.Errorf("participants = %v, want 2", got.Participants)
		}
	})
}
