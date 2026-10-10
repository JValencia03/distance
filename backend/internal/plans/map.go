package plans

import (
	"cmp"
	"math"
	"net/http"
	"slices"
	"time"
)

// maxMapPlans bounds the map response; the soonest plans win.
const maxMapPlans = 40

// mapZone is a zone placed on the map. X and Y are normalized to 0..1
// (x grows east, y grows south) and keep the zones' relative layout without
// sending their coordinates.
type mapZone struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	X    float64 `json:"x"`
	Y    float64 `json:"y"`
}

var mapZones = layoutZones(zones)

// layoutZones projects zone centers onto a square with a 10% margin,
// keeping their aspect ratio. Longitudes are scaled by the cosine of the
// mean latitude so east-west and north-south distances match.
func layoutZones(all []Zone) []mapZone {
	if len(all) == 0 {
		return nil
	}
	var meanLat float64
	for _, z := range all {
		meanLat += z.Lat
	}
	meanLat /= float64(len(all))
	scale := math.Cos(meanLat * math.Pi / 180)

	minX, maxX := math.Inf(1), math.Inf(-1)
	minY, maxY := math.Inf(1), math.Inf(-1)
	for _, z := range all {
		x := z.Lng * scale
		minX, maxX = min(minX, x), max(maxX, x)
		minY, maxY = min(minY, z.Lat), max(maxY, z.Lat)
	}
	span := max(maxX-minX, maxY-minY)
	if span == 0 {
		span = 1
	}
	// Center the shorter axis.
	offsetX := (span - (maxX - minX)) / 2
	offsetY := (span - (maxY - minY)) / 2
	round := func(v float64) float64 { return math.Round(v*1000) / 1000 }

	result := make([]mapZone, len(all))
	for i, z := range all {
		x := (z.Lng*scale - minX + offsetX) / span
		y := (maxY - z.Lat + offsetY) / span
		result[i] = mapZone{ID: z.ID, Name: z.Name, X: round(0.1 + 0.8*x), Y: round(0.1 + 0.8*y)}
	}
	return result
}

// mapParticipant is how a participant appears on the map: their avatar and
// the zone they chose, never their id.
type mapParticipant struct {
	Avatar Avatar `json:"avatar"`
	ZoneID string `json:"zoneId"`
	IsMe   bool   `json:"isMe"`
}

type mapPlan struct {
	planResponse
	Participants []mapParticipant `json:"participants"`
}

// visiblePlans returns active plans that have not ended, optionally of one
// activity, soonest first and at most maxMapPlans.
func visiblePlans(all []Plan, activityID string, now time.Time) []Plan {
	result := []Plan{}
	for _, p := range all {
		if p.Status != StatusActive || !p.EndsAt().After(now) {
			continue
		}
		if activityID != "" && p.Activity.ID != activityID {
			continue
		}
		result = append(result, p)
	}
	slices.SortFunc(result, func(a, b Plan) int {
		return cmp.Or(a.StartsAt.Compare(b.StartsAt), cmp.Compare(a.ID, b.ID))
	})
	if len(result) > maxMapPlans {
		result = result[:maxMapPlans]
	}
	return result
}

// getMap returns the zone layout and the upcoming and ongoing plans with the
// avatars of their participants.
func (h *Handler) getMap(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	activityID := r.URL.Query().Get("activity")
	if activityID != "" {
		if _, ok := findActivity(activityID); !ok {
			writeError(w, lang, http.StatusBadRequest, "invalid_query", msgInvalidActivity, map[string]text{"activity": msgUnknownActivity})
			return
		}
	}

	now := h.now()
	current, err := h.store.Current(r.Context(), now)
	if err != nil {
		writeInternalError(w, lang, "map plans", err)
		return
	}
	found := visiblePlans(current, activityID, now)

	var userIDs []string
	for _, p := range found {
		for _, pt := range p.Participants {
			userIDs = append(userIDs, pt.UserID)
		}
	}
	slices.Sort(userIDs)
	avatars, err := avatarsFor(r.Context(), h.avatars, slices.Compact(userIDs))
	if err != nil {
		writeInternalError(w, lang, "map avatars", err)
		return
	}

	viewer := userID(r)
	plans := make([]mapPlan, len(found))
	for i, p := range found {
		participants := make([]mapParticipant, len(p.Participants))
		for j, pt := range p.Participants {
			participants[j] = mapParticipant{
				Avatar: avatars[pt.UserID],
				ZoneID: pt.Zone.ID,
				IsMe:   viewer != "" && pt.UserID == viewer,
			}
		}
		plans[i] = mapPlan{planResponse: toResponse(p, viewer, lang, now), Participants: participants}
	}
	writeJSON(w, http.StatusOK, map[string]any{"zones": mapZones, "plans": plans})
}
