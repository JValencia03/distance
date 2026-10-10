package plans

import (
	"net/http"
	"os"
	"strings"
	"testing"

	"distance/internal/database"
)

const validAvatar = `{"skin": "basic", "bodyColor": "mint", "skinTone": "tone3", "accessory": "cap"}`

func TestAvatarOptions(t *testing.T) {
	mux, _ := newTestServer(t)

	rec := do(t, mux, "GET", "/avatar-options", "", map[string]string{"Accept-Language": "en"})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	got := decode[struct {
		Skins       []catalogItem
		BodyColors  []string
		SkinTones   []string
		Accessories []catalogItem
	}](t, rec)
	if len(got.Skins) != 1 || got.Skins[0] != (catalogItem{ID: "basic", Name: "Basic"}) {
		t.Errorf("skins = %+v", got.Skins)
	}
	if len(got.BodyColors) != len(avatarBodyColors) || len(got.SkinTones) != len(avatarSkinTones) {
		t.Errorf("colors = %v, tones = %v", got.BodyColors, got.SkinTones)
	}
	if len(got.Accessories) == 0 || got.Accessories[0] != (catalogItem{ID: "none", Name: "None"}) {
		t.Errorf("accessories = %+v", got.Accessories)
	}
}

func TestMyAvatar(t *testing.T) {
	mux, _ := newTestServer(t)

	rec := do(t, mux, "GET", "/me/avatar", "", asUser)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body)
	}
	first := decode[avatarResponse](t, rec)
	if !first.IsDefault || first.Avatar != defaultAvatar("user-1") || first.Avatar.validate() != nil {
		t.Errorf("default avatar = %+v", first)
	}

	rec = do(t, mux, "PUT", "/me/avatar", validAvatar, asUser)
	if rec.Code != http.StatusOK {
		t.Fatalf("save status = %d, body = %s", rec.Code, rec.Body)
	}
	want := Avatar{Skin: "basic", BodyColor: "mint", SkinTone: "tone3", Accessory: "cap"}
	if got := decode[avatarResponse](t, rec); got.IsDefault || got.Avatar != want {
		t.Errorf("saved = %+v", got)
	}

	rec = do(t, mux, "GET", "/me/avatar", "", asUser)
	if got := decode[avatarResponse](t, rec); got.IsDefault || got.Avatar != want {
		t.Errorf("after saving = %+v", got)
	}
	// Other users keep their own default.
	rec = do(t, mux, "GET", "/me/avatar", "", joinAs("someone-else"))
	if got := decode[avatarResponse](t, rec); !got.IsDefault {
		t.Errorf("another user's avatar = %+v", got)
	}
}

func TestSaveAvatarRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name      string
		body      string
		headers   map[string]string
		wantCode  int
		wantField string
	}{
		{"missing user", validAvatar, nil, http.StatusUnauthorized, ""},
		{"malformed json", `{`, asUser, http.StatusBadRequest, ""},
		{"unknown field", strings.Replace(validAvatar, `"cap"`, `"cap", "hat": "x"`, 1), asUser, http.StatusBadRequest, ""},
		{"unknown skin", strings.Replace(validAvatar, `"basic"`, `"dragon"`, 1), asUser, http.StatusUnprocessableEntity, "skin"},
		{"unknown color", strings.Replace(validAvatar, `"mint"`, `"#ff0000"`, 1), asUser, http.StatusUnprocessableEntity, "bodyColor"},
		{"unknown tone", strings.Replace(validAvatar, `"tone3"`, `"tone9"`, 1), asUser, http.StatusUnprocessableEntity, "skinTone"},
		{"missing accessory", `{"skin": "basic", "bodyColor": "mint", "skinTone": "tone3"}`, asUser, http.StatusUnprocessableEntity, "accessory"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mux, _ := newTestServer(t)
			rec := do(t, mux, "PUT", "/me/avatar", tt.body, tt.headers)
			if rec.Code != tt.wantCode {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, tt.wantCode, rec.Body)
			}
			if resp := decode[errorResponse](t, rec); tt.wantField != "" && resp.Error.Fields[tt.wantField] == "" {
				t.Errorf("missing field error %q: %+v", tt.wantField, resp.Error)
			}
			rec = do(t, mux, "GET", "/me/avatar", "", asUser)
			if got := decode[avatarResponse](t, rec); !got.IsDefault {
				t.Errorf("invalid avatar was saved: %+v", got)
			}
		})
	}
}

func TestDefaultAvatarIsStableAndVaried(t *testing.T) {
	if defaultAvatar("ana") != defaultAvatar("ana") {
		t.Error("default avatar changes between calls")
	}
	seen := map[Avatar]bool{}
	for _, id := range []string{"a", "b", "c", "d", "e", "f", "g", "h"} {
		a := defaultAvatar(id)
		if a.validate() != nil {
			t.Errorf("default avatar of %q is invalid: %+v", id, a)
		}
		seen[a] = true
	}
	if len(seen) < 4 {
		t.Errorf("only %d distinct default avatars for 8 users", len(seen))
	}
}

// testAvatarStore checks the behavior every AvatarStore must provide.
func testAvatarStore(t *testing.T, newStore func(t *testing.T) AvatarStore) {
	t.Run("save, replace and read", func(t *testing.T) {
		store := newStore(t)
		if _, ok, err := store.Avatar(t.Context(), "ana"); err != nil || ok {
			t.Fatalf("before saving: ok = %v, err = %v", ok, err)
		}
		first := Avatar{Skin: "basic", BodyColor: "mint", SkinTone: "tone1", Accessory: "none"}
		second := Avatar{Skin: "basic", BodyColor: "coral", SkinTone: "tone6", Accessory: "glasses"}
		if err := store.SaveAvatar(t.Context(), "ana", first); err != nil {
			t.Fatal(err)
		}
		if err := store.SaveAvatar(t.Context(), "ana", second); err != nil {
			t.Fatal(err)
		}
		if got, ok, err := store.Avatar(t.Context(), "ana"); err != nil || !ok || got != second {
			t.Errorf("avatar = %+v, %v, %v; want %+v", got, ok, err, second)
		}
	})

	t.Run("avatars of several users", func(t *testing.T) {
		store := newStore(t)
		saved := Avatar{Skin: "basic", BodyColor: "sky", SkinTone: "tone2", Accessory: "flower"}
		if err := store.SaveAvatar(t.Context(), "ana", saved); err != nil {
			t.Fatal(err)
		}
		got, err := avatarsFor(t.Context(), store, []string{"ana", "bruno"})
		if err != nil {
			t.Fatal(err)
		}
		if len(got) != 2 || got["ana"] != saved || got["bruno"] != defaultAvatar("bruno") {
			t.Errorf("avatars = %+v", got)
		}
		if empty, err := store.Avatars(t.Context(), nil); err != nil || len(empty) != 0 {
			t.Errorf("no users: %v, %v", empty, err)
		}
	})
}

func TestMemoryAvatarStore(t *testing.T) {
	testAvatarStore(t, func(*testing.T) AvatarStore { return NewMemoryAvatarStore() })
}

// TestPostgresAvatarStore deletes all avatars, so point
// DISTANCE_TEST_DATABASE_URL at a disposable database.
func TestPostgresAvatarStore(t *testing.T) {
	url := os.Getenv("DISTANCE_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("DISTANCE_TEST_DATABASE_URL not set")
	}
	pool, err := database.Open(t.Context(), url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := database.Migrate(t.Context(), pool); err != nil {
		t.Fatal(err)
	}
	testAvatarStore(t, func(t *testing.T) AvatarStore {
		if _, err := pool.Exec(t.Context(), "TRUNCATE user_avatars"); err != nil {
			t.Fatal(err)
		}
		return NewPostgresAvatarStore(pool)
	})
}
