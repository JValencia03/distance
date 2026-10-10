package plans

import (
	"cmp"
	"errors"
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
	minDuration       = 15 * time.Minute
	maxDuration       = 12 * time.Hour
	defaultDuration   = time.Hour
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
	Duration        time.Duration
	MaxParticipants int // 0 means no limit.
	CreatorID       string
	Status          Status
	// Participants are in joining order; the creator comes first.
	Participants []Participant
}

// Participant is a user taking part in a plan, with the zone they chose to
// show when joining. Zones are coarse on purpose: unlike user ids, they will
// be visible to other users.
type Participant struct {
	UserID string
	Zone   Zone
}

// EndsAt is when the plan finishes; people can join until then.
func (p Plan) EndsAt() time.Time {
	return p.StartsAt.Add(p.Duration)
}

// isOngoing reports whether the plan has started but not ended at now.
func (p Plan) isOngoing(now time.Time) bool {
	return !p.StartsAt.After(now) && p.EndsAt().After(now)
}

// Status is the lifecycle state of a plan. There is no way to cancel a plan
// yet; the state exists so joining rules and storage already account for it.
type Status string

const (
	StatusActive    Status = "active"
	StatusCancelled Status = "cancelled"
)

// Errors returned when a plan cannot be found or joined.
var (
	errNotFound      = errors.New("plan not found")
	errAlreadyJoined = errors.New("user already joined the plan")
	errPlanFull      = errors.New("plan is full")
	errPlanCancelled = errors.New("plan is cancelled")
	errPlanEnded     = errors.New("plan has already ended")
)

func (p Plan) isFull() bool {
	return p.MaxParticipants > 0 && len(p.Participants) >= p.MaxParticipants
}

func (p Plan) hasParticipant(userID string) bool {
	return slices.ContainsFunc(p.Participants, func(pt Participant) bool { return pt.UserID == userID })
}

// canJoin reports why userID cannot join the plan at time now, or nil if it
// can. Plans can be joined before they start and while they are ongoing.
// Stores must call it while holding whatever lock protects the plan.
func (p Plan) canJoin(userID string, now time.Time) error {
	switch {
	case p.Status == StatusCancelled:
		return errPlanCancelled
	case !p.EndsAt().After(now):
		return errPlanEnded
	case p.hasParticipant(userID):
		return errAlreadyJoined
	case p.isFull():
		return errPlanFull
	}
	return nil
}

// NewPlanInput is the client payload for creating a plan.
type NewPlanInput struct {
	ActivityID      string    `json:"activityId"`
	Title           string    `json:"title"`
	Description     *string   `json:"description"`
	ZoneID          string    `json:"zoneId"`
	Place           string    `json:"place"`
	StartsAt        time.Time `json:"startsAt"`
	DurationMinutes *int      `json:"durationMinutes"`
	MaxParticipants *int      `json:"maxParticipants"`
	// CreatorZoneID is the zone the creator shows to others. It defaults to
	// the plan's zone.
	CreatorZoneID *string `json:"creatorZoneId"`
}

// newPlan validates the input and builds a plan whose first participant is
// its creator. On failure it returns the problems keyed by JSON field name.
func newPlan(in NewPlanInput, id, creatorID string, now time.Time) (Plan, map[string]text) {
	problems := map[string]text{}

	activity, ok := findActivity(in.ActivityID)
	if !ok {
		problems["activityId"] = text{"Actividad desconocida.", "Unknown activity."}
	}
	zone, ok := findZone(in.ZoneID)
	if !ok {
		problems["zoneId"] = text{"Zona desconocida.", "Unknown zone."}
	}

	title := strings.TrimSpace(in.Title)
	switch {
	case title == "":
		problems["title"] = text{"El título es obligatorio.", "Title is required."}
	case utf8.RuneCountInString(title) > maxTitleLen:
		problems["title"] = text{"El título es demasiado largo.", "Title is too long."}
	}

	var description string
	if in.Description != nil {
		description = strings.TrimSpace(*in.Description)
		if utf8.RuneCountInString(description) > maxDescriptionLen {
			problems["description"] = text{"La descripción es demasiado larga.", "Description is too long."}
		}
	}

	place := strings.TrimSpace(in.Place)
	switch {
	case place == "":
		problems["place"] = text{"El lugar de encuentro es obligatorio.", "Meeting point is required."}
	case utf8.RuneCountInString(place) > maxPlaceLen:
		problems["place"] = text{"El lugar de encuentro es demasiado largo.", "Meeting point is too long."}
	}

	switch {
	case in.StartsAt.IsZero():
		problems["startsAt"] = text{"La fecha y hora son obligatorias.", "Date and time are required."}
	case !in.StartsAt.After(now):
		problems["startsAt"] = text{"La fecha y hora deben ser futuras.", "Date and time must be in the future."}
	}

	duration := defaultDuration
	if in.DurationMinutes != nil {
		duration = time.Duration(*in.DurationMinutes) * time.Minute
		if duration < minDuration || duration > maxDuration {
			problems["durationMinutes"] = text{"La duración debe estar entre 15 minutos y 12 horas.", "The duration must be between 15 minutes and 12 hours."}
		}
	}

	creatorZone := zone
	if in.CreatorZoneID != nil {
		if creatorZone, ok = findZone(*in.CreatorZoneID); !ok {
			problems["creatorZoneId"] = text{"Zona desconocida.", "Unknown zone."}
		}
	}

	var limit int
	if in.MaxParticipants != nil {
		limit = *in.MaxParticipants
		if limit < minParticipants || limit > maxParticipants {
			problems["maxParticipants"] = text{"El límite debe estar entre 2 y 50 participantes.", "The limit must be between 2 and 50 participants."}
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
		Duration:        duration,
		MaxParticipants: limit,
		CreatorID:       creatorID,
		Status:          StatusActive,
		Participants:    []Participant{{UserID: creatorID, Zone: creatorZone}},
	}, nil
}

// discoveredPlan is a plan plus its distance to the reference zone.
type discoveredPlan struct {
	Plan
	DistanceKm float64
}

// discover returns active plans that have not ended, optionally filtered by
// activity: available ones first, then nearest to the reference zone, then
// soonest. Ongoing plans start earlier, so they come first at equal distance.
func discover(all []Plan, from Zone, activityID string, now time.Time) []discoveredPlan {
	result := []discoveredPlan{}
	for _, p := range all {
		if p.Status != StatusActive || !p.EndsAt().After(now) {
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
