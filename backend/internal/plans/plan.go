package plans

import (
	"cmp"
	"math"
	"slices"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	maxTitleLen       = 80
	maxDescriptionLen = 500
	maxPlaceLen       = 120
	minParticipants   = 2
	maxParticipants   = 50
)

// Plan is a concrete intention to do an activity at a meeting point and time.
type Plan struct {
	ID              string
	Activity        Activity
	Title           string
	Description     string
	Zone            Zone
	Place           string
	StartsAt        time.Time
	MaxParticipants int // 0 means no limit.
	CreatorID       string
	Participants    []string
}

func (p Plan) isFull() bool {
	return p.MaxParticipants > 0 && len(p.Participants) >= p.MaxParticipants
}

// NewPlanInput is the client payload for creating a plan.
type NewPlanInput struct {
	ActivityID      string    `json:"activityId"`
	Title           string    `json:"title"`
	Description     *string   `json:"description"`
	ZoneID          string    `json:"zoneId"`
	Place           string    `json:"place"`
	StartsAt        time.Time `json:"startsAt"`
	MaxParticipants *int      `json:"maxParticipants"`
}

// newPlan validates the input and builds a plan whose first participant is
// its creator. On failure it returns the problems keyed by JSON field name.
func newPlan(in NewPlanInput, id, creatorID string, now time.Time) (Plan, map[string]string) {
	problems := map[string]string{}

	activity, ok := findActivity(in.ActivityID)
	if !ok {
		problems["activityId"] = "Actividad desconocida."
	}
	zone, ok := findZone(in.ZoneID)
	if !ok {
		problems["zoneId"] = "Zona desconocida."
	}

	title := strings.TrimSpace(in.Title)
	switch {
	case title == "":
		problems["title"] = "El título es obligatorio."
	case utf8.RuneCountInString(title) > maxTitleLen:
		problems["title"] = "El título es demasiado largo."
	}

	var description string
	if in.Description != nil {
		description = strings.TrimSpace(*in.Description)
		if utf8.RuneCountInString(description) > maxDescriptionLen {
			problems["description"] = "La descripción es demasiado larga."
		}
	}

	place := strings.TrimSpace(in.Place)
	switch {
	case place == "":
		problems["place"] = "El lugar de encuentro es obligatorio."
	case utf8.RuneCountInString(place) > maxPlaceLen:
		problems["place"] = "El lugar de encuentro es demasiado largo."
	}

	switch {
	case in.StartsAt.IsZero():
		problems["startsAt"] = "La fecha y hora son obligatorias."
	case !in.StartsAt.After(now):
		problems["startsAt"] = "La fecha y hora deben ser futuras."
	}

	var limit int
	if in.MaxParticipants != nil {
		limit = *in.MaxParticipants
		if limit < minParticipants || limit > maxParticipants {
			problems["maxParticipants"] = "El límite debe estar entre 2 y 50 participantes."
		}
	}

	if len(problems) > 0 {
		return Plan{}, problems
	}
	return Plan{
		ID:              id,
		Activity:        activity,
		Title:           title,
		Description:     description,
		Zone:            zone,
		Place:           place,
		StartsAt:        in.StartsAt.UTC(),
		MaxParticipants: limit,
		CreatorID:       creatorID,
		Participants:    []string{creatorID},
	}, nil
}

// discoveredPlan is a plan plus its distance to the reference zone.
type discoveredPlan struct {
	Plan
	DistanceKm float64
}

// discover returns future plans, optionally filtered by activity, available
// ones first, then nearest to the reference zone, then soonest.
func discover(all []Plan, from Zone, activityID string, now time.Time) []discoveredPlan {
	result := []discoveredPlan{}
	for _, p := range all {
		if !p.StartsAt.After(now) {
			continue
		}
		if activityID != "" && p.Activity.ID != activityID {
			continue
		}
		result = append(result, discoveredPlan{Plan: p, DistanceKm: distanceKm(from, p.Zone)})
	}
	slices.SortFunc(result, func(a, b discoveredPlan) int {
		if a.isFull() != b.isFull() {
			if a.isFull() {
				return 1
			}
			return -1
		}
		return cmp.Or(
			cmp.Compare(a.DistanceKm, b.DistanceKm),
			a.StartsAt.Compare(b.StartsAt),
		)
	})
	return result
}

// distanceKm is the haversine distance between zone centers, rounded to
// 0.1 km. Rounding keeps the value useful for ordering without suggesting
// more precision than zones provide.
func distanceKm(a, b Zone) float64 {
	const earthRadiusKm = 6371.0
	toRad := func(deg float64) float64 { return deg * math.Pi / 180 }
	dLat := toRad(b.Lat - a.Lat)
	dLng := toRad(b.Lng - a.Lng)
	h := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(toRad(a.Lat))*math.Cos(toRad(b.Lat))*math.Sin(dLng/2)*math.Sin(dLng/2)
	d := 2 * earthRadiusKm * math.Asin(math.Sqrt(h))
	return math.Round(d*10) / 10
}
