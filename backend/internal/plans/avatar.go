package plans

import (
	"hash/fnv"
	"slices"
)

// Avatar is the character a user is drawn as on the plans map. Skin names a
// character model; the other fields customize it. Every field is an id from
// the catalogs below, which the app maps to its own colors and shapes, so
// the server never stores free-form styling.
type Avatar struct {
	Skin      string `json:"skin"`
	BodyColor string `json:"bodyColor"`
	SkinTone  string `json:"skinTone"`
	Accessory string `json:"accessory"`
}

// avatarOption is a catalog entry with a name shown to users.
type avatarOption struct {
	ID   string
	Name text
}

// Only the basic skin exists for now; more models will be added as skins
// without changing the customization fields.
var avatarSkins = []avatarOption{
	{ID: "basic", Name: text{"Básico", "Basic"}},
}

// Colors are ids the app maps to its palette, so they can be retuned there
// without migrating stored avatars.
var (
	avatarBodyColors = []string{"coral", "mint", "lavender", "sky", "sunflower", "peach", "forest", "charcoal"}
	avatarSkinTones  = []string{"tone1", "tone2", "tone3", "tone4", "tone5", "tone6"}
)

var avatarAccessories = []avatarOption{
	{ID: "none", Name: text{"Ninguno", "None"}},
	{ID: "cap", Name: text{"Gorra", "Cap"}},
	{ID: "beanie", Name: text{"Gorro", "Beanie"}},
	{ID: "headphones", Name: text{"Audífonos", "Headphones"}},
	{ID: "flower", Name: text{"Flor", "Flower"}},
	{ID: "glasses", Name: text{"Gafas", "Glasses"}},
}

func hasOption(options []avatarOption, id string) bool {
	return slices.ContainsFunc(options, func(o avatarOption) bool { return o.ID == id })
}

// validate returns the problems keyed by JSON field name, or nil.
func (a Avatar) validate() map[string]text {
	problems := map[string]text{}
	if !hasOption(avatarSkins, a.Skin) {
		problems["skin"] = text{"Aspecto desconocido.", "Unknown skin."}
	}
	if !slices.Contains(avatarBodyColors, a.BodyColor) {
		problems["bodyColor"] = text{"Color desconocido.", "Unknown color."}
	}
	if !slices.Contains(avatarSkinTones, a.SkinTone) {
		problems["skinTone"] = text{"Tono de piel desconocido.", "Unknown skin tone."}
	}
	if !hasOption(avatarAccessories, a.Accessory) {
		problems["accessory"] = text{"Accesorio desconocido.", "Unknown accessory."}
	}
	if len(problems) == 0 {
		return nil
	}
	return problems
}

// defaultAvatar is the avatar of a user who has not customized one. It is
// derived from the user id so it stays the same across requests and the map
// shows varied characters before anyone customizes theirs.
func defaultAvatar(userID string) Avatar {
	h := fnv.New64a()
	h.Write([]byte(userID))
	n := h.Sum64()
	pick := func(count int) int {
		i := int(n % uint64(count))
		n /= uint64(count)
		return i
	}
	return Avatar{
		Skin:      avatarSkins[0].ID,
		BodyColor: avatarBodyColors[pick(len(avatarBodyColors))],
		SkinTone:  avatarSkinTones[pick(len(avatarSkinTones))],
		// Accessories are a choice; defaults stay plain.
		Accessory: "none",
	}
}
