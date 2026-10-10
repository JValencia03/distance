package plans

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRequestLang(t *testing.T) {
	tests := []struct {
		header string
		want   Lang
	}{
		{"", Spanish},
		{"en", English},
		{"en-US,en;q=0.9", English},
		{"ES-co", Spanish},
		{"fr-FR,fr;q=0.9", Spanish},
		{"fr,en;q=0.8,es;q=0.5", English},
		{"es;q=0.4,en;q=0.6", English},
		{"en;q=0.5,es;q=0.5", English},
		{"en;q=0,es", Spanish},
		{"en;q=abc", Spanish},
		{"*", Spanish},
	}
	for _, tt := range tests {
		r := httptest.NewRequest("GET", "/", nil)
		r.Header.Set("Accept-Language", tt.header)
		if got := requestLang(r); got != tt.want {
			t.Errorf("requestLang(%q) = %q, want %q", tt.header, got, tt.want)
		}
	}
}

func TestResponsesFollowAcceptLanguage(t *testing.T) {
	mux, store := newTestServer(t)
	seedPlan(t, store, "p", nil)
	english := map[string]string{"Accept-Language": "en-US"}

	rec := do(t, mux, "GET", "/activities", "", english)
	acts := decode[struct{ Activities []catalogItem }](t, rec)
	if acts.Activities[0] != (catalogItem{ID: "reading", Name: "Reading"}) {
		t.Errorf("first activity = %+v", acts.Activities[0])
	}
	if vary := rec.Header().Get("Vary"); vary != "Accept-Language" {
		t.Errorf("Vary = %q", vary)
	}

	rec = do(t, mux, "GET", "/plans/p", "", english)
	if got := decode[planResponse](t, rec); got.Activity.Name != "Reading" || got.Title != "Leer" {
		t.Errorf("plan activity = %q, title = %q; want translated activity and untouched title", got.Activity.Name, got.Title)
	}

	rec = do(t, mux, "GET", "/plans/p", "", nil)
	if got := decode[planResponse](t, rec); got.Activity.Name != "Leer" {
		t.Errorf("default activity name = %q, want Spanish", got.Activity.Name)
	}

	rec = do(t, mux, "POST", "/plans/p/participants", joinBody, map[string]string{userIDHeader: "creator", "Accept-Language": "en"})
	if got := decode[errorResponse](t, rec); got.Error.Message != "You already participate in this plan." {
		t.Errorf("error message = %q", got.Error.Message)
	}

	rec = do(t, mux, "POST", "/plans", `{"activityId":"reading"}`, map[string]string{userIDHeader: "u", "Accept-Language": "en"})
	got := decode[errorResponse](t, rec)
	if rec.Code != http.StatusUnprocessableEntity || got.Error.Message != "Check the plan details." || got.Error.Fields["title"] != "Title is required." {
		t.Errorf("validation error = %d %+v", rec.Code, got.Error)
	}
}
