package plans

import (
	"fmt"
	"net/http"
	"sync"
	"testing"
	"time"
)

// seedPlan stores an active one-hour plan starting in one hour, created by
// "creator", after applying edit.
func seedPlan(t *testing.T, store Store, id string, edit func(*Plan)) {
	t.Helper()
	reading, _ := findActivity("reading")
	chapinero, _ := findZone("chapinero")
	p := Plan{
		ID:           id,
		Activity:     reading,
		Title:        "Leer",
		Zone:         chapinero,
		Place:        "Café",
		StartsAt:     testNow.Add(time.Hour),
		Duration:     time.Hour,
		CreatorID:    "creator",
		Status:       StatusActive,
		Participants: people("creator"),
	}
	if edit != nil {
		edit(&p)
	}
	if err := store.Create(t.Context(), p); err != nil {
		t.Fatalf("seed plan: %v", err)
	}
}

// people builds participants that show the Chapinero zone.
func people(userIDs ...string) []Participant {
	chapinero, _ := findZone("chapinero")
	result := make([]Participant, len(userIDs))
	for i, id := range userIDs {
		result[i] = Participant{UserID: id, Zone: chapinero}
	}
	return result
}

func participantIDs(p Plan) []string {
	ids := make([]string, len(p.Participants))
	for i, pt := range p.Participants {
		ids[i] = pt.UserID
	}
	return ids
}

const joinBody = `{"zoneId": "suba"}`

func joinAs(userID string) map[string]string {
	return map[string]string{userIDHeader: userID}
}

func TestJoinPlan(t *testing.T) {
	mux, store := newTestServer(t)
	seedPlan(t, store, "p", func(p *Plan) { p.MaxParticipants = 3 })

	rec := do(t, mux, "POST", "/plans/p/participants", joinBody, joinAs("ana"))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	got := decode[planResponse](t, rec)
	if got.ParticipantCount != 2 || !got.IsParticipant || got.IsFull || got.Status != StatusActive {
		t.Errorf("unexpected plan after joining: %+v", got)
	}

	tests := []struct {
		viewer map[string]string
		want   bool
	}{
		{joinAs("ana"), true},
		{joinAs("creator"), true},
		{joinAs("someone-else"), false},
		{nil, false},
	}
	for _, tt := range tests {
		rec := do(t, mux, "GET", "/plans/p", "", tt.viewer)
		if got := decode[planResponse](t, rec); got.IsParticipant != tt.want {
			t.Errorf("GET as %v: isParticipant = %v, want %v", tt.viewer, got.IsParticipant, tt.want)
		}
	}

	rec = do(t, mux, "POST", "/plans/p/participants", joinBody, joinAs("bruno"))
	if got := decode[planResponse](t, rec); got.ParticipantCount != 3 || !got.IsFull {
		t.Errorf("last spot not reflected: %+v", got)
	}

	stored, _ := store.Get(t.Context(), "p")
	var zones []string
	for _, pt := range stored.Participants {
		zones = append(zones, pt.Zone.ID)
	}
	if fmt.Sprint(zones) != "[chapinero suba suba]" {
		t.Errorf("participant zones = %v, want the creator's and the chosen ones", zones)
	}
}

func TestJoinOngoingPlan(t *testing.T) {
	for _, startsAt := range []time.Time{testNow, testNow.Add(-59 * time.Minute)} {
		mux, store := newTestServer(t)
		seedPlan(t, store, "p", func(p *Plan) { p.StartsAt = startsAt })

		rec := do(t, mux, "POST", "/plans/p/participants", joinBody, joinAs("ana"))
		if rec.Code != http.StatusOK {
			t.Fatalf("starting at %v: status = %d, body = %s", startsAt, rec.Code, rec.Body)
		}
		if got := decode[planResponse](t, rec); !got.IsOngoing || !got.IsParticipant {
			t.Errorf("starting at %v: plan = %+v, want ongoing and joined", startsAt, got)
		}
	}
}

func TestJoinPlanRequiresZone(t *testing.T) {
	tests := []struct {
		name     string
		body     string
		wantCode int
		wantErr  string
	}{
		{"empty body", "", http.StatusBadRequest, "invalid_json"},
		{"unknown field", `{"zoneId": "suba", "lat": 4.6}`, http.StatusBadRequest, "invalid_json"},
		{"missing zone", `{}`, http.StatusUnprocessableEntity, "validation_failed"},
		{"unknown zone", `{"zoneId": "mars"}`, http.StatusUnprocessableEntity, "validation_failed"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mux, store := newTestServer(t)
			seedPlan(t, store, "p", nil)

			rec := do(t, mux, "POST", "/plans/p/participants", tt.body, joinAs("ana"))
			if rec.Code != tt.wantCode {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, tt.wantCode, rec.Body)
			}
			got := decode[errorResponse](t, rec)
			if got.Error.Code != tt.wantErr {
				t.Errorf("error code = %q, want %q", got.Error.Code, tt.wantErr)
			}
			if tt.wantCode == http.StatusUnprocessableEntity && got.Error.Fields["zoneId"] == "" {
				t.Errorf("missing zoneId field error: %+v", got.Error)
			}
			if p, _ := store.Get(t.Context(), "p"); len(p.Participants) != 1 {
				t.Errorf("participants changed on rejection: %v", p.Participants)
			}
		})
	}
}

func TestJoinPlanRejections(t *testing.T) {
	tests := []struct {
		name     string
		planID   string
		user     map[string]string
		edit     func(*Plan)
		wantCode int
		wantErr  string
	}{
		{"missing identity", "p", nil, nil, http.StatusUnauthorized, "unauthenticated"},
		{"blank identity", "p", joinAs("   "), nil, http.StatusUnauthorized, "unauthenticated"},
		{"unknown plan", "missing", joinAs("ana"), nil, http.StatusNotFound, "not_found"},
		{"creator already participates", "p", joinAs("creator"), nil, http.StatusConflict, "already_joined"},
		{"full plan", "p", joinAs("ana"), func(p *Plan) {
			p.MaxParticipants = 2
			p.Participants = people("creator", "bruno")
		}, http.StatusConflict, "plan_full"},
		{"cancelled plan", "p", joinAs("ana"), func(p *Plan) { p.Status = StatusCancelled }, http.StatusConflict, "plan_cancelled"},
		{"plan ending now", "p", joinAs("ana"), func(p *Plan) { p.StartsAt = testNow.Add(-time.Hour) }, http.StatusConflict, "plan_ended"},
		{"plan ended long ago", "p", joinAs("ana"), func(p *Plan) { p.StartsAt = testNow.Add(-48 * time.Hour) }, http.StatusConflict, "plan_ended"},
		{"ongoing but full", "p", joinAs("ana"), func(p *Plan) {
			p.StartsAt = testNow.Add(-time.Minute)
			p.MaxParticipants = 2
			p.Participants = people("creator", "bruno")
		}, http.StatusConflict, "plan_full"},
		{"cancelled takes precedence over full", "p", joinAs("ana"), func(p *Plan) {
			p.Status = StatusCancelled
			p.MaxParticipants = 2
			p.Participants = people("creator", "bruno")
		}, http.StatusConflict, "plan_cancelled"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mux, store := newTestServer(t)
			seedPlan(t, store, "p", tt.edit)
			before, _ := store.Get(t.Context(), "p")

			rec := do(t, mux, "POST", "/plans/"+tt.planID+"/participants", joinBody, tt.user)
			if rec.Code != tt.wantCode {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, tt.wantCode, rec.Body)
			}
			if got := decode[errorResponse](t, rec); got.Error.Code != tt.wantErr {
				t.Errorf("error code = %q, want %q", got.Error.Code, tt.wantErr)
			}
			after, _ := store.Get(t.Context(), "p")
			if len(after.Participants) != len(before.Participants) {
				t.Errorf("participants changed on rejection: %v -> %v", before.Participants, after.Participants)
			}
		})
	}
}

func TestJoinPlanConcurrentRequestsRespectLimit(t *testing.T) {
	mux, store := newTestServer(t)
	const limit, requests = 5, 50
	seedPlan(t, store, "p", func(p *Plan) { p.MaxParticipants = limit })

	codes := make([]int, requests)
	var wg sync.WaitGroup
	for i := range requests {
		wg.Go(func() {
			rec := do(t, mux, "POST", "/plans/p/participants", joinBody, joinAs(fmt.Sprintf("user-%d", i)))
			codes[i] = rec.Code
		})
	}
	wg.Wait()

	joined := 0
	for _, code := range codes {
		switch code {
		case http.StatusOK:
			joined++
		case http.StatusConflict:
		default:
			t.Errorf("unexpected status %d", code)
		}
	}
	if joined != limit-1 {
		t.Errorf("%d joins succeeded, want %d", joined, limit-1)
	}
	if p, _ := store.Get(t.Context(), "p"); len(p.Participants) != limit {
		t.Errorf("plan has %d participants, want %d", len(p.Participants), limit)
	}
}

func TestJoinPlanSameUserConcurrently(t *testing.T) {
	mux, store := newTestServer(t)
	seedPlan(t, store, "p", nil)

	var wg sync.WaitGroup
	for range 20 {
		wg.Go(func() { do(t, mux, "POST", "/plans/p/participants", joinBody, joinAs("ana")) })
	}
	wg.Wait()

	if p, _ := store.Get(t.Context(), "p"); len(p.Participants) != 2 {
		t.Errorf("participants = %v, want creator and ana once", p.Participants)
	}
}

func TestDiscoveryExcludesCancelledPlans(t *testing.T) {
	mux, store := newTestServer(t)
	seedPlan(t, store, "active", nil)
	seedPlan(t, store, "cancelled", func(p *Plan) { p.Status = StatusCancelled })

	rec := do(t, mux, "GET", "/plans?zone=chapinero", "", joinAs("creator"))
	got := decode[struct{ Plans []planResponse }](t, rec)
	if len(got.Plans) != 1 || got.Plans[0].ID != "active" || !got.Plans[0].IsParticipant {
		t.Errorf("plans = %+v, want only the active one, marked as joined", got.Plans)
	}
}
