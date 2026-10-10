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

// Handler serves the activities, zones, plans, avatar and map endpoints.
// Catalog names and error messages follow the request's Accept-Language
// (see requestLang).
type Handler struct {
	store   Store
	avatars AvatarStore
	now     func() time.Time
	newID   func() string
}

func NewHandler(store Store, avatars AvatarStore) *Handler {
	return &Handler{store: store, avatars: avatars, now: time.Now, newID: randomID}
}

// Register adds the routes to mux.
func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /activities", h.listActivities)
	mux.HandleFunc("GET /zones", h.listZones)
	mux.HandleFunc("GET /plans", h.listPlans)
	mux.HandleFunc("GET /plans/{id}", h.getPlan)
	mux.HandleFunc("POST /plans", h.createPlan)
	mux.HandleFunc("POST /plans/{id}/participants", h.joinPlan)
	mux.HandleFunc("GET /avatar-options", h.listAvatarOptions)
	mux.HandleFunc("GET /me/avatar", h.getMyAvatar)
	mux.HandleFunc("PUT /me/avatar", h.saveMyAvatar)
	mux.HandleFunc("GET /map", h.getMap)
}

// catalogItem is an activity as sent to clients, named in one language.
type catalogItem struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func localize(a Activity, lang Lang) catalogItem {
	return catalogItem{ID: a.ID, Name: a.Name.in(lang)}
}

type planResponse struct {
	ID               string      `json:"id"`
	Activity         catalogItem `json:"activity"`
	Title            string      `json:"title"`
	Description      *string     `json:"description"`
	Zone             Zone        `json:"zone"`
	Place            string      `json:"place"`
	StartsAt         time.Time   `json:"startsAt"`
	DurationMinutes  int         `json:"durationMinutes"`
	EndsAt           time.Time   `json:"endsAt"`
	IsOngoing        bool        `json:"isOngoing"`
	Status           Status      `json:"status"`
	ParticipantCount int         `json:"participantCount"`
	MaxParticipants  *int        `json:"maxParticipants"`
	IsFull           bool        `json:"isFull"`
	IsParticipant    bool        `json:"isParticipant"`
	DistanceKm       *float64    `json:"distanceKm,omitempty"`
}

// toResponse renders a plan for viewerID, who may be empty when the request
// carries no identity, at time now. Participant ids are never exposed.
// Titles and descriptions are written by users and are not translated.
func toResponse(p Plan, viewerID string, lang Lang, now time.Time) planResponse {
	r := planResponse{
		ID:               p.ID,
		Activity:         localize(p.Activity, lang),
		Title:            p.Title,
		Zone:             p.Zone,
		Place:            p.Place,
		StartsAt:         p.StartsAt,
		DurationMinutes:  int(p.Duration / time.Minute),
		EndsAt:           p.EndsAt(),
		IsOngoing:        p.isOngoing(now),
		Status:           p.Status,
		ParticipantCount: len(p.Participants),
		IsFull:           p.isFull(),
		IsParticipant:    viewerID != "" && p.hasParticipant(viewerID),
	}
	if p.Description != "" {
		r.Description = &p.Description
	}
	if p.MaxParticipants > 0 {
		r.MaxParticipants = &p.MaxParticipants
	}
	return r
}

// userID returns the development identity from X-User-Id, or "" when it is
// missing or invalid. There is no authentication yet: the client declares
// who it is. Do not treat this as a security boundary.
func userID(r *http.Request) string {
	id := strings.TrimSpace(r.Header.Get(userIDHeader))
	if utf8.RuneCountInString(id) > maxUserIDLen {
		return ""
	}
	return id
}

// Error messages, by error code.
var (
	msgInvalidZone     = text{"Indica una zona válida.", "Provide a valid zone."}
	msgUnknownZone     = text{"Zona desconocida.", "Unknown zone."}
	msgInvalidActivity = text{"La actividad no existe.", "The activity does not exist."}
	msgUnknownActivity = text{"Actividad desconocida.", "Unknown activity."}
	msgUnauthenticated = text{"Falta un identificador de usuario válido.", "A valid user identifier is required."}
	msgNotFound        = text{"El plan no existe.", "The plan does not exist."}
	msgBodyTooLarge    = text{"La solicitud es demasiado grande.", "The request is too large."}
	msgInvalidJSON     = text{"El cuerpo de la solicitud no es JSON válido.", "The request body is not valid JSON."}
	msgValidation      = text{"Revisa los datos del plan.", "Check the plan details."}
	msgAlreadyJoined   = text{"Ya participas en este plan.", "You already participate in this plan."}
	msgPlanFull        = text{"El plan ya no tiene plazas disponibles.", "The plan has no spots left."}
	msgPlanCancelled   = text{"El plan fue cancelado.", "The plan was cancelled."}
	msgPlanEnded       = text{"El plan ya terminó.", "The plan has already ended."}
	msgInternal        = text{"Ocurrió un error inesperado. Inténtalo de nuevo.", "Something went wrong. Please try again."}
)

func (h *Handler) listActivities(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	items := make([]catalogItem, len(activities))
	for i, a := range activities {
		items[i] = localize(a, lang)
	}
	writeJSON(w, http.StatusOK, map[string]any{"activities": items})
}

func (h *Handler) listZones(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"zones": zones})
}

func (h *Handler) listPlans(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	query := r.URL.Query()
	zone, ok := findZone(query.Get("zone"))
	if !ok {
		writeError(w, lang, http.StatusBadRequest, "invalid_query", msgInvalidZone, map[string]text{"zone": msgUnknownZone})
		return
	}
	activityID := query.Get("activity")
	if activityID != "" {
		if _, ok := findActivity(activityID); !ok {
			writeError(w, lang, http.StatusBadRequest, "invalid_query", msgInvalidActivity, map[string]text{"activity": msgUnknownActivity})
			return
		}
	}

	now := h.now()
	current, err := h.store.Current(r.Context(), now)
	if err != nil {
		writeInternalError(w, lang, "list plans", err)
		return
	}
	viewer := userID(r)
	found := discover(current, zone, activityID, now)
	result := make([]planResponse, 0, len(found))
	for _, d := range found {
		resp := toResponse(d.Plan, viewer, lang, now)
		resp.DistanceKm = &d.DistanceKm
		result = append(result, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"plans": result})
}

func (h *Handler) getPlan(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	p, err := h.store.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, errNotFound) {
		writeError(w, lang, http.StatusNotFound, "not_found", msgNotFound, nil)
		return
	}
	if err != nil {
		writeInternalError(w, lang, "get plan", err)
		return
	}
	writeJSON(w, http.StatusOK, toResponse(p, userID(r), lang, h.now()))
}

// decodeBody reads a JSON body into v, rejecting unknown fields. On failure
// it writes the error response and returns false.
func decodeBody(w http.ResponseWriter, r *http.Request, lang Lang, v any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBody))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			writeError(w, lang, http.StatusRequestEntityTooLarge, "body_too_large", msgBodyTooLarge, nil)
			return false
		}
		writeError(w, lang, http.StatusBadRequest, "invalid_json", msgInvalidJSON, nil)
		return false
	}
	return true
}

func (h *Handler) createPlan(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	creatorID := userID(r)
	if creatorID == "" {
		writeError(w, lang, http.StatusUnauthorized, "unauthenticated", msgUnauthenticated, nil)
		return
	}

	var in NewPlanInput
	if !decodeBody(w, r, lang, &in) {
		return
	}

	now := h.now()
	p, problems := newPlan(in, h.newID(), creatorID, now)
	if problems != nil {
		writeError(w, lang, http.StatusUnprocessableEntity, "validation_failed", msgValidation, problems)
		return
	}
	if err := h.store.Create(r.Context(), p); err != nil {
		writeInternalError(w, lang, "create plan", err)
		return
	}

	w.Header().Set("Location", "/plans/"+p.ID)
	writeJSON(w, http.StatusCreated, toResponse(p, creatorID, lang, now))
}

// joinInput is the client payload for joining a plan.
type joinInput struct {
	// ZoneID is the zone the participant chooses to show to others.
	ZoneID string `json:"zoneId"`
}

// joinPlan adds the caller to a plan and responds with the updated plan.
func (h *Handler) joinPlan(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	participantID := userID(r)
	if participantID == "" {
		writeError(w, lang, http.StatusUnauthorized, "unauthenticated", msgUnauthenticated, nil)
		return
	}

	var in joinInput
	if !decodeBody(w, r, lang, &in) {
		return
	}
	zone, ok := findZone(in.ZoneID)
	if !ok {
		writeError(w, lang, http.StatusUnprocessableEntity, "validation_failed", msgInvalidZone, map[string]text{"zoneId": msgUnknownZone})
		return
	}

	now := h.now()
	p, err := h.store.Join(r.Context(), r.PathValue("id"), Participant{UserID: participantID, Zone: zone}, now)
	switch {
	case err == nil:
		writeJSON(w, http.StatusOK, toResponse(p, participantID, lang, now))
	case errors.Is(err, errNotFound):
		writeError(w, lang, http.StatusNotFound, "not_found", msgNotFound, nil)
	case errors.Is(err, errAlreadyJoined):
		writeError(w, lang, http.StatusConflict, "already_joined", msgAlreadyJoined, nil)
	case errors.Is(err, errPlanFull):
		writeError(w, lang, http.StatusConflict, "plan_full", msgPlanFull, nil)
	case errors.Is(err, errPlanCancelled):
		writeError(w, lang, http.StatusConflict, "plan_cancelled", msgPlanCancelled, nil)
	case errors.Is(err, errPlanEnded):
		writeError(w, lang, http.StatusConflict, "plan_ended", msgPlanEnded, nil)
	default:
		writeInternalError(w, lang, "join plan", err)
	}
}

type errorBody struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
}

func writeError(w http.ResponseWriter, lang Lang, status int, code string, message text, fields map[string]text) {
	body := errorBody{Code: code, Message: message.in(lang)}
	if len(fields) > 0 {
		body.Fields = make(map[string]string, len(fields))
		for field, problem := range fields {
			body.Fields[field] = problem.in(lang)
		}
	}
	writeJSON(w, status, map[string]errorBody{"error": body})
}

// writeInternalError logs the cause and hides it from the client.
func writeInternalError(w http.ResponseWriter, lang Lang, action string, err error) {
	log.Printf("%s: %v", action, err)
	writeError(w, lang, http.StatusInternalServerError, "internal_error", msgInternal, nil)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	// Responses depend on the request language; caches must key on it.
	w.Header().Add("Vary", "Accept-Language")
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
