package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"distance/internal/plans"
)

func TestHealth(t *testing.T) {
	rec := httptest.NewRecorder()
	newMux(plans.NewMemoryStore()).ServeHTTP(rec, httptest.NewRequest("GET", "/health", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"status":"ok"}` {
		t.Errorf("body = %s", got)
	}
}
