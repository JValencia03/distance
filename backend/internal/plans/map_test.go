package plans

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

type mapResponse struct {
	Zones []mapZone
	Plans []struct {
		planResponse
		Participants []mapParticipant
	}
}

func TestMapShowsParticipantsWithAvatarsAndZones(t *testing.T) {
	mux, store := newTestServer(t)
	seedPlan(t, store, "ongoing", func(p *Plan) { p.StartsAt = testNow.Add(-10 * time.Minute) })
	seedPlan(t, store, "later", func(p *Plan) { p.StartsAt = testNow.Add(3 * time.Hour) })
	seedPlan(t, store, "ended", func(p *Plan) { p.StartsAt = testNow.Add(-2 * time.Hour) })
	seedPlan(t, store, "cancelled", func(p *Plan) { p.Status = StatusCancelled })
	do(t, mux, "PUT", "/me/avatar", validAvatar, joinAs("ana"))
	do(t, mux, "POST", "/plans/ongoing/participants", `{"zoneId": "kennedy"}`, joinAs("ana"))

	rec := do(t, mux, "GET", "/map", "", joinAs("ana"))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	body := rec.Body.String()
	for _, leak := range []string{"creator", `"ana"`, `"lat"`, `"lng"`} {
		if strings.Contains(body, leak) {
			t.Errorf("map exposes %s: %s", leak, body)
		}
	}
	got := decode[mapResponse](t, rec)

	if len(got.Plans) != 2 || got.Plans[0].ID != "ongoing" || got.Plans[1].ID != "later" {
		t.Fatalf("plans = %+v, want ongoing then later", got.Plans)
	}
	ongoing := got.Plans[0]
	if !ongoing.IsOngoing || !ongoing.IsParticipant || len(ongoing.Participants) != 2 {
		t.Fatalf("ongoing plan = %+v", ongoing)
	}
	creator, ana := ongoing.Participants[0], ongoing.Participants[1]
	if creator.IsMe || creator.ZoneID != "chapinero" || creator.Avatar != defaultAvatar("creator") {
		t.Errorf("creator = %+v", creator)
	}
	wantAna := Avatar{Skin: "basic", BodyColor: "mint", SkinTone: "tone3", Accessory: "cap"}
	if !ana.IsMe || ana.ZoneID != "kennedy" || ana.Avatar != wantAna {
		t.Errorf("ana = %+v", ana)
	}
	if got.Plans[1].Participants[0].IsMe {
		t.Error("isMe set for another user")
	}
}

func TestMapFiltersByActivity(t *testing.T) {
	mux, store := newTestServer(t)
	running, _ := findActivity("running")
	seedPlan(t, store, "reading", nil)
	seedPlan(t, store, "running", func(p *Plan) { p.Activity = running })

	got := decode[mapResponse](t, do(t, mux, "GET", "/map?activity=running", "", nil))
	if len(got.Plans) != 1 || got.Plans[0].ID != "running" {
		t.Errorf("plans = %+v", got.Plans)
	}
	if rec := do(t, mux, "GET", "/map?activity=skydiving", "", nil); rec.Code != http.StatusBadRequest {
		t.Errorf("unknown activity status = %d", rec.Code)
	}
	// Without an identity nobody is "me".
	if got.Plans[0].Participants[0].IsMe || got.Plans[0].IsParticipant {
		t.Error("anonymous viewer marked as participant")
	}
}

func TestMapLimitsPlans(t *testing.T) {
	mux, store := newTestServer(t)
	for i := range maxMapPlans + 5 {
		seedPlan(t, store, string(rune('A'+i)), func(p *Plan) {
			p.StartsAt = testNow.Add(time.Duration(i+1) * time.Minute)
		})
	}
	got := decode[mapResponse](t, do(t, mux, "GET", "/map", "", nil))
	if len(got.Plans) != maxMapPlans || got.Plans[0].ID != "A" {
		t.Errorf("got %d plans starting with %q", len(got.Plans), got.Plans[0].ID)
	}
}

func TestZoneLayout(t *testing.T) {
	if len(mapZones) != len(zones) {
		t.Fatalf("layout has %d zones, want %d", len(mapZones), len(zones))
	}
	byID := map[string]mapZone{}
	for _, z := range mapZones {
		if z.X < 0.1 || z.X > 0.9 || z.Y < 0.1 || z.Y > 0.9 {
			t.Errorf("%s at (%v, %v) is outside the margins", z.ID, z.X, z.Y)
		}
		byID[z.ID] = z
	}
	// Suba is north-west of La Candelaria: smaller x and y.
	suba, candelaria := byID["suba"], byID["candelaria"]
	if suba.X >= candelaria.X || suba.Y >= candelaria.Y {
		t.Errorf("suba %+v should be north-west of candelaria %+v", suba, candelaria)
	}
	if single := layoutZones(zones[:1]); single[0].X != 0.5 || single[0].Y != 0.5 {
		t.Errorf("a single zone is placed at (%v, %v), want the center", single[0].X, single[0].Y)
	}
}
