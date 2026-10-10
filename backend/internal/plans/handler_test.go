package plans

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

var testNow = time.Date(2026, 10, 9, 12, 0, 0, 0, time.UTC)

func newTestServer(t *testing.T) (*http.ServeMux, *MemoryStore) {
	t.Helper()
	store := NewMemoryStore()
	h := NewHandler(store, NewMemoryAvatarStore())
	h.now = func() time.Time { return testNow }
	n := 0
	h.newID = func() string { n++; return fmt.Sprintf("plan-%d", n) }
	mux := http.NewServeMux()
	h.Register(mux)
	return mux, store
}

func do(t *testing.T, mux http.Handler, method, target, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func decode[T any](t *testing.T, rec *httptest.ResponseRecorder) T {
	t.Helper()
	var v T
	if err := json.NewDecoder(rec.Body).Decode(&v); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return v
}

type errorResponse struct {
	Error errorBody `json:"error"`
}

const validBody = `{
	"activityId": "reading",
	"title": "  Leer en el café  ",
	"description": null,
	"zoneId": "chapinero",
	"place": "Café Libro",
	"startsAt": "2026-10-09T22:00:00Z",
	"maxParticipants": 4
}`

var asUser = map[string]string{userIDHeader: "user-1"}

func TestCatalogs(t *testing.T) {
	mux, _ := newTestServer(t)

	rec := do(t, mux, "GET", "/activities", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("activities status = %d", rec.Code)
	}
	acts := decode[struct{ Activities []catalogItem }](t, rec)
	if len(acts.Activities) != 10 {
		t.Errorf("got %d activities, want 10", len(acts.Activities))
	}

	rec = do(t, mux, "GET", "/zones", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("zones status = %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "lat") {
		t.Errorf("zones response exposes coordinates: %s", rec.Body.String())
	}
}

func TestCreatePlan(t *testing.T) {
	mux, store := newTestServer(t)

	rec := do(t, mux, "POST", "/plans", validBody, asUser)
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	if got := rec.Header().Get("Location"); got != "/plans/plan-1" {
		t.Errorf("Location = %q", got)
	}
	got := decode[planResponse](t, rec)
	if got.Title != "Leer en el café" {
		t.Errorf("title not trimmed: %q", got.Title)
	}
	if got.ParticipantCount != 1 || got.IsFull || got.Description != nil {
		t.Errorf("unexpected plan: %+v", got)
	}
	if got.Activity.Name != "Leer" || got.Zone.Name != "Chapinero" {
		t.Errorf("catalog names not embedded: %+v", got)
	}

	if got.DurationMinutes != 60 || !got.EndsAt.Equal(got.StartsAt.Add(time.Hour)) || got.IsOngoing {
		t.Errorf("default duration not applied: %+v", got)
	}

	stored, err := store.Get(t.Context(), "plan-1")
	if err != nil || stored.CreatorID != "user-1" || len(stored.Participants) != 1 ||
		stored.Participants[0].UserID != "user-1" || stored.Participants[0].Zone.ID != "chapinero" {
		t.Errorf("creator not registered as participant in the plan's zone: %+v", stored)
	}
}

func TestCreatePlanWithDurationAndCreatorZone(t *testing.T) {
	mux, store := newTestServer(t)
	body := strings.Replace(validBody, `"maxParticipants": 4`,
		`"maxParticipants": 4, "durationMinutes": 90, "creatorZoneId": "suba"`, 1)

	rec := do(t, mux, "POST", "/plans", body, asUser)
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	got := decode[planResponse](t, rec)
	if got.DurationMinutes != 90 || !got.EndsAt.Equal(time.Date(2026, 10, 9, 23, 30, 0, 0, time.UTC)) {
		t.Errorf("duration = %d, endsAt = %v", got.DurationMinutes, got.EndsAt)
	}
	if got.Zone.ID != "chapinero" {
		t.Errorf("plan zone = %q, want chapinero", got.Zone.ID)
	}
	if stored, _ := store.Get(t.Context(), "plan-1"); stored.Participants[0].Zone.ID != "suba" {
		t.Errorf("creator zone = %q, want suba", stored.Participants[0].Zone.ID)
	}
}

func TestCreatePlanRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name      string
		body      string
		headers   map[string]string
		wantCode  int
		wantField string
	}{
		{"missing user", validBody, nil, http.StatusUnauthorized, ""},
		{"malformed json", `{`, asUser, http.StatusBadRequest, ""},
		{"unknown field", `{"foo":1}`, asUser, http.StatusBadRequest, ""},
		{"blank title", strings.Replace(validBody, `"  Leer en el café  "`, `"   "`, 1), asUser, http.StatusUnprocessableEntity, "title"},
		{"unknown activity", strings.Replace(validBody, `"reading"`, `"skydiving"`, 1), asUser, http.StatusUnprocessableEntity, "activityId"},
		{"unknown zone", strings.Replace(validBody, `"chapinero"`, `"mars"`, 1), asUser, http.StatusUnprocessableEntity, "zoneId"},
		{"missing place", strings.Replace(validBody, `"Café Libro"`, `""`, 1), asUser, http.StatusUnprocessableEntity, "place"},
		{"past date", strings.Replace(validBody, "2026-10-09T22:00:00Z", "2026-10-09T11:59:00Z", 1), asUser, http.StatusUnprocessableEntity, "startsAt"},
		{"now is not future", strings.Replace(validBody, "2026-10-09T22:00:00Z", "2026-10-09T12:00:00Z", 1), asUser, http.StatusUnprocessableEntity, "startsAt"},
		{"missing date", strings.Replace(validBody, `"startsAt": "2026-10-09T22:00:00Z",`, "", 1), asUser, http.StatusUnprocessableEntity, "startsAt"},
		{"limit too low", strings.Replace(validBody, `"maxParticipants": 4`, `"maxParticipants": 1`, 1), asUser, http.StatusUnprocessableEntity, "maxParticipants"},
		{"limit too high", strings.Replace(validBody, `"maxParticipants": 4`, `"maxParticipants": 51`, 1), asUser, http.StatusUnprocessableEntity, "maxParticipants"},
		{"duration too short", strings.Replace(validBody, `"maxParticipants": 4`, `"maxParticipants": 4, "durationMinutes": 14`, 1), asUser, http.StatusUnprocessableEntity, "durationMinutes"},
		{"duration too long", strings.Replace(validBody, `"maxParticipants": 4`, `"maxParticipants": 4, "durationMinutes": 721`, 1), asUser, http.StatusUnprocessableEntity, "durationMinutes"},
		{"unknown creator zone", strings.Replace(validBody, `"maxParticipants": 4`, `"maxParticipants": 4, "creatorZoneId": "mars"`, 1), asUser, http.StatusUnprocessableEntity, "creatorZoneId"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mux, store := newTestServer(t)
			rec := do(t, mux, "POST", "/plans", tt.body, tt.headers)
			if rec.Code != tt.wantCode {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, tt.wantCode, rec.Body)
			}
			resp := decode[errorResponse](t, rec)
			if tt.wantField != "" && resp.Error.Fields[tt.wantField] == "" {
				t.Errorf("missing field error %q: %+v", tt.wantField, resp.Error)
			}
			if all, _ := store.Current(t.Context(), testNow); len(all) != 0 {
				t.Error("invalid plan was stored")
			}
		})
	}
}

func TestGetPlan(t *testing.T) {
	mux, _ := newTestServer(t)
	do(t, mux, "POST", "/plans", validBody, asUser)

	rec := do(t, mux, "GET", "/plans/plan-1", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "distanceKm") || strings.Contains(rec.Body.String(), "user-1") {
		t.Errorf("detail exposes unexpected fields: %s", rec.Body)
	}

	rec = do(t, mux, "GET", "/plans/missing", "", nil)
	if rec.Code != http.StatusNotFound {
		t.Errorf("missing plan status = %d", rec.Code)
	}
}

func TestListPlans(t *testing.T) {
	mux, store := newTestServer(t)
	at := func(h int) time.Time { return testNow.Add(time.Duration(h) * time.Hour) }
	chapinero, _ := findZone("chapinero")
	usaquen, _ := findZone("usaquen")
	reading, _ := findActivity("reading")
	running, _ := findActivity("running")

	store.Create(t.Context(), Plan{ID: "past", Activity: reading, Zone: chapinero, StartsAt: at(-1), Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "ended", Activity: reading, Zone: chapinero, StartsAt: at(-3), Duration: 2 * time.Hour, Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "ongoing", Activity: reading, Zone: usaquen, StartsAt: at(-1), Duration: 2 * time.Hour, Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "far-soon", Activity: reading, Zone: usaquen, StartsAt: at(1), Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "near-late", Activity: reading, Zone: chapinero, StartsAt: at(5), Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "near-soon", Activity: reading, Zone: chapinero, StartsAt: at(2), Status: StatusActive, Participants: people("a")})
	store.Create(t.Context(), Plan{ID: "near-full", Activity: reading, Zone: chapinero, StartsAt: at(1), MaxParticipants: 2, Status: StatusActive, Participants: people("a", "b")})
	store.Create(t.Context(), Plan{ID: "other-activity", Activity: running, Zone: chapinero, StartsAt: at(1), Status: StatusActive, Participants: people("a")})

	rec := do(t, mux, "GET", "/plans?zone=chapinero&activity=reading", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	got := decode[struct{ Plans []planResponse }](t, rec)
	var ids []string
	for _, p := range got.Plans {
		ids = append(ids, p.ID)
	}
	// The ongoing plan sorts by distance like any other available plan.
	want := []string{"near-soon", "near-late", "ongoing", "far-soon", "near-full"}
	if fmt.Sprint(ids) != fmt.Sprint(want) {
		t.Fatalf("order = %v, want %v", ids, want)
	}
	if got.Plans[0].DistanceKm == nil || *got.Plans[0].DistanceKm != 0 {
		t.Errorf("same-zone distance = %v, want 0", got.Plans[0].DistanceKm)
	}
	if !got.Plans[2].IsOngoing || got.Plans[0].IsOngoing {
		t.Error("ongoing state not reported")
	}
	if !got.Plans[4].IsFull {
		t.Error("full plan not flagged")
	}

	rec = do(t, mux, "GET", "/plans?zone=chapinero", "", nil)
	if all := decode[struct{ Plans []planResponse }](t, rec); len(all.Plans) != 6 {
		t.Errorf("without activity filter got %d plans, want 6", len(all.Plans))
	}
}

func TestListPlansEmptyAndInvalidQueries(t *testing.T) {
	mux, _ := newTestServer(t)

	rec := do(t, mux, "GET", "/plans?zone=chapinero", "", nil)
	if rec.Code != http.StatusOK || strings.TrimSpace(rec.Body.String()) != `{"plans":[]}` {
		t.Errorf("empty list = %d %s", rec.Code, rec.Body)
	}

	for _, target := range []string{"/plans", "/plans?zone=mars", "/plans?zone=chapinero&activity=skydiving"} {
		if rec := do(t, mux, "GET", target, "", nil); rec.Code != http.StatusBadRequest {
			t.Errorf("%s status = %d, want 400", target, rec.Code)
		}
	}
}
