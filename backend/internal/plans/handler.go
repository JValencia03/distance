package plans

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	userIDHeader   = "X-User-Id"
	maxUserIDLen   = 64
	maxRequestBody = 16 << 10
)

// Handler serves the activities, zones and plans endpoints.
type Handler struct {
	store *MemoryStore
	now   func() time.Time
	newID func() string
}

func NewHandler(store *MemoryStore) *Handler {
	return &Handler{store: store, now: time.Now, newID: randomID}
}

// Register adds the plan routes to mux.
func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /activities", h.listActivities)
	mux.HandleFunc("GET /zones", h.listZones)
	mux.HandleFunc("GET /plans", h.listPlans)
	mux.HandleFunc("GET /plans/{id}", h.getPlan)
	mux.HandleFunc("POST /plans", h.createPlan)
}

type planResponse struct {
	ID               string    `json:"id"`
	Activity         Activity  `json:"activity"`
	Title            string    `json:"title"`
	Description      *string   `json:"description"`
	Zone             Zone      `json:"zone"`
	Place            string    `json:"place"`
	StartsAt         time.Time `json:"startsAt"`
	ParticipantCount int       `json:"participantCount"`
	MaxParticipants  *int      `json:"maxParticipants"`
	IsFull           bool      `json:"isFull"`
	DistanceKm       *float64  `json:"distanceKm,omitempty"`
}

func toResponse(p Plan) planResponse {
	r := planResponse{
		ID:               p.ID,
		Activity:         p.Activity,
		Title:            p.Title,
		Zone:             p.Zone,
		Place:            p.Place,
		StartsAt:         p.StartsAt,
		ParticipantCount: len(p.Participants),
		IsFull:           p.isFull(),
	}
	if p.Description != "" {
		r.Description = &p.Description
	}
	if p.MaxParticipants > 0 {
		r.MaxParticipants = &p.MaxParticipants
	}
	return r
}

func (h *Handler) listActivities(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"activities": activities})
}

func (h *Handler) listZones(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"zones": zones})
}

func (h *Handler) listPlans(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	zone, ok := findZone(query.Get("zone"))
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_query", "Indica una zona válida.", map[string]string{"zone": "Zona desconocida."})
		return
	}
	activityID := query.Get("activity")
	if activityID != "" {
		if _, ok := findActivity(activityID); !ok {
			writeError(w, http.StatusBadRequest, "invalid_query", "La actividad no existe.", map[string]string{"activity": "Actividad desconocida."})
			return
		}
	}

	found := discover(h.store.all(), zone, activityID, h.now())
	result := make([]planResponse, 0, len(found))
	for _, d := range found {
		resp := toResponse(d.Plan)
		resp.DistanceKm = &d.DistanceKm
		result = append(result, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"plans": result})
}

func (h *Handler) getPlan(w http.ResponseWriter, r *http.Request) {
	p, ok := h.store.get(r.PathValue("id"))
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "El plan no existe.", nil)
		return
	}
	writeJSON(w, http.StatusOK, toResponse(p))
}

func (h *Handler) createPlan(w http.ResponseWriter, r *http.Request) {
	// Development-only identity: there is no authentication yet, so the
	// client declares who it is. Do not treat this as a security boundary.
	userID := strings.TrimSpace(r.Header.Get(userIDHeader))
	if userID == "" || utf8.RuneCountInString(userID) > maxUserIDLen {
		writeError(w, http.StatusUnauthorized, "unauthenticated", "Falta un identificador de usuario válido.", nil)
		return
	}

	var in NewPlanInput
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBody))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", "La solicitud es demasiado grande.", nil)
			return
		}
		writeError(w, http.StatusBadRequest, "invalid_json", "El cuerpo de la solicitud no es JSON válido.", nil)
		return
	}

	p, problems := newPlan(in, h.newID(), userID, h.now())
	if problems != nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Revisa los datos del plan.", problems)
		return
	}
	h.store.add(p)

	w.Header().Set("Location", "/plans/"+p.ID)
	writeJSON(w, http.StatusCreated, toResponse(p))
}

type errorBody struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
}

func writeError(w http.ResponseWriter, status int, code, message string, fields map[string]string) {
	writeJSON(w, status, map[string]errorBody{"error": {Code: code, Message: message, Fields: fields}})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		log.Printf("write response: %v", err)
	}
}

func randomID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b) // crypto/rand.Read never returns an error since Go 1.24.
	return hex.EncodeToString(b)
}
