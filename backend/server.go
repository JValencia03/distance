package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"distance/internal/database"
	"distance/internal/plans"
)

func main() {
	ctx := context.Background()

	var (
		store   plans.Store
		avatars plans.AvatarStore
	)
	if databaseURL := os.Getenv("DATABASE_URL"); databaseURL != "" {
		pool, err := database.Open(ctx, databaseURL)
		if err != nil {
			log.Fatal(err)
		}
		defer pool.Close()
		if err := database.Migrate(ctx, pool); err != nil {
			log.Fatal(err)
		}
		store = plans.NewPostgresStore(pool)
		avatars = plans.NewPostgresAvatarStore(pool)
		log.Print("storage: PostgreSQL")
	} else {
		store = plans.NewMemoryStore()
		avatars = plans.NewMemoryAvatarStore()
		log.Print("storage: in memory (set DATABASE_URL to use PostgreSQL); data is lost on restart")
	}

	log.Print("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", newMux(store, avatars)))
}

func newMux(store plans.Store, avatars plans.AvatarStore) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
	plans.NewHandler(store, avatars).Register(mux)
	return mux
}
