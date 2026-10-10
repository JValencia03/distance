package plans

import "net/http"

var (
	msgInvalidAvatar = text{"Revisa los datos del personaje.", "Check the character details."}
)

func localizeOptions(options []avatarOption, lang Lang) []catalogItem {
	items := make([]catalogItem, len(options))
	for i, o := range options {
		items[i] = catalogItem{ID: o.ID, Name: o.Name.in(lang)}
	}
	return items
}

// listAvatarOptions returns every value an avatar field accepts. Colors are
// ids without names: the app shows them as swatches.
func (h *Handler) listAvatarOptions(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	writeJSON(w, http.StatusOK, map[string]any{
		"skins":       localizeOptions(avatarSkins, lang),
		"bodyColors":  avatarBodyColors,
		"skinTones":   avatarSkinTones,
		"accessories": localizeOptions(avatarAccessories, lang),
	})
}

type avatarResponse struct {
	Avatar Avatar `json:"avatar"`
	// IsDefault is true until the user saves an avatar of their own.
	IsDefault bool `json:"isDefault"`
}

func (h *Handler) getMyAvatar(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	user := userID(r)
	if user == "" {
		writeError(w, lang, http.StatusUnauthorized, "unauthenticated", msgUnauthenticated, nil)
		return
	}
	a, ok, err := h.avatars.Avatar(r.Context(), user)
	if err != nil {
		writeInternalError(w, lang, "get avatar", err)
		return
	}
	if !ok {
		a = defaultAvatar(user)
	}
	writeJSON(w, http.StatusOK, avatarResponse{Avatar: a, IsDefault: !ok})
}

// saveMyAvatar replaces the caller's avatar. Every field is required, so the
// app always sends the whole avatar it shows.
func (h *Handler) saveMyAvatar(w http.ResponseWriter, r *http.Request) {
	lang := requestLang(r)
	user := userID(r)
	if user == "" {
		writeError(w, lang, http.StatusUnauthorized, "unauthenticated", msgUnauthenticated, nil)
		return
	}
	var a Avatar
	if !decodeBody(w, r, lang, &a) {
		return
	}
	if problems := a.validate(); problems != nil {
		writeError(w, lang, http.StatusUnprocessableEntity, "validation_failed", msgInvalidAvatar, problems)
		return
	}
	if err := h.avatars.SaveAvatar(r.Context(), user, a); err != nil {
		writeInternalError(w, lang, "save avatar", err)
		return
	}
	writeJSON(w, http.StatusOK, avatarResponse{Avatar: a})
}
