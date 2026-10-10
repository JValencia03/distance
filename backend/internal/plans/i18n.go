package plans

import (
	"net/http"
	"strconv"
	"strings"
)

// Lang is a language the API can respond in.
type Lang string

const (
	Spanish Lang = "es"
	English Lang = "en"
)

// defaultLang is used when the request accepts no supported language.
const defaultLang = Spanish

// text is a user-facing string in every supported language.
type text struct {
	es, en string
}

func (t text) in(lang Lang) string {
	if lang == English {
		return t.en
	}
	return t.es
}

// requestLang picks the response language from the Accept-Language header:
// the supported language with the highest quality, the first one on ties.
// Region subtags are ignored, so "en-US" selects English.
func requestLang(r *http.Request) Lang {
	best, bestQ := defaultLang, 0.0
	for part := range strings.SplitSeq(r.Header.Get("Accept-Language"), ",") {
		tag, params, _ := strings.Cut(strings.TrimSpace(part), ";")
		q := 1.0
		if value, ok := strings.CutPrefix(strings.TrimSpace(params), "q="); ok {
			parsed, err := strconv.ParseFloat(value, 64)
			if err != nil {
				continue
			}
			q = parsed
		}
		primary, _, _ := strings.Cut(strings.ToLower(tag), "-")
		lang := Lang(primary)
		if (lang == Spanish || lang == English) && q > bestQ {
			best, bestQ = lang, q
		}
	}
	return best
}
