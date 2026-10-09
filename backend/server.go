package main

import (
	"encoding/json"
	"log"
	"net/http"

	"distance/internal/plans"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", newMux(plans.NewMemoryStore())))
}

func newMux(store *plans.MemoryStore) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
	plans.NewHandler(store).Register(mux)
	return mux
}
