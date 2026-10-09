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
	h := NewHandler(store)
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
	acts := decode[struct{ Activities []Activity }](t, rec)
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

	stored, ok := store.get("plan-1")
	if !ok || stored.CreatorID != "user-1" || len(stored.Participants) != 1 || stored.Participants[0] != "user-1" {
		t.Errorf("creator not registered as participant: %+v", stored)
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
			if len(store.all()) != 0 {
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

	store.add(Plan{ID: "past", Activity: reading, Zone: chapinero, StartsAt: at(-1), Participants: []string{"a"}})
	store.add(Plan{ID: "far-soon", Activity: reading, Zone: usaquen, StartsAt: at(1), Participants: []string{"a"}})
	store.add(Plan{ID: "near-late", Activity: reading, Zone: chapinero, StartsAt: at(5), Participants: []string{"a"}})
	store.add(Plan{ID: "near-soon", Activity: reading, Zone: chapinero, StartsAt: at(2), Participants: []string{"a"}})
	store.add(Plan{ID: "near-full", Activity: reading, Zone: chapinero, StartsAt: at(1), MaxParticipants: 2, Participants: []string{"a", "b"}})
	store.add(Plan{ID: "other-activity", Activity: running, Zone: chapinero, StartsAt: at(1), Participants: []string{"a"}})

	rec := do(t, mux, "GET", "/plans?zone=chapinero&activity=reading", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	got := decode[struct{ Plans []planResponse }](t, rec)
	var ids []string
	for _, p := range got.Plans {
		ids = append(ids, p.ID)
	}
	want := []string{"near-soon", "near-late", "far-soon", "near-full"}
	if fmt.Sprint(ids) != fmt.Sprint(want) {
		t.Errorf("order = %v, want %v", ids, want)
	}
	if got.Plans[0].DistanceKm == nil || *got.Plans[0].DistanceKm != 0 {
		t.Errorf("same-zone distance = %v, want 0", got.Plans[0].DistanceKm)
	}
	if !got.Plans[3].IsFull {
		t.Error("full plan not flagged")
	}

	rec = do(t, mux, "GET", "/plans?zone=chapinero", "", nil)
	if all := decode[struct{ Plans []planResponse }](t, rec); len(all.Plans) != 5 {
		t.Errorf("without activity filter got %d plans, want 5", len(all.Plans))
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
